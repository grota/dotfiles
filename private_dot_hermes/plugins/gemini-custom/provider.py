"""``gemini-custom`` — a Hermes TTS provider for the Gemini 3.x speech API.

Design notes worth keeping:

* Every knob is re-read from ``tts.providers.gemini-custom`` on each call, so an
  edit applies to the next reply without restarting the gateway. Nothing is
  cached except the voice catalogue.
* Single speaker, one turn, the reply text is the transcript. Gemini 3.8 treats
  input as verbatim, so delivery is steered by ``speech_metadata.style`` and by
  inline tags in the text — never by direction words inside the text.
  (Multi-speaker dialogue was removed: the API accepts exactly two speakers, and
  when turns were configured the reply text was discarded, so the provider could
  never speak what Hermes actually asked for.)
* The per-request chunk cap is NOT a plugin setting. Hermes splits the text
  before calling us and reads the cap from ``tts.gemini-custom.max_text_length``
  — the flat ``tts.<provider>`` namespace where the built-in engines keep theirs
  (``tts.gemini``, ``tts.edge``). ``tools/limits.py`` derives a safe cap from the
  model's published token window (8 192 input tokens for the 3.8 TTS models).
* Audio is requested as ``audio/l16`` by default and wrapped here, because the
  built-in adapter blindly prepends a RIFF header — which double-wraps the WAV
  that Gemini 3.8 returns and leaves a 0.9 ms click of header bytes as PCM.
* ``stream()`` yields headerless 24 kHz mono int16 PCM, matching
  ``streams_pcm`` / ``stream_sample_rate`` for Hermes' live voice path.
"""

from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Iterator, Optional

from agent.tts_provider import TTSProvider

from . import gemini_api as api

CONFIG_KEY = "gemini-custom"

DEFAULTS: dict[str, Any] = {
    "model": "gemini-3.8-flash-tts",
    "voice": "Kore",
    "language": "",          # only used when voice == "auto": pick a catalogue voice for this locale
    "style": "",             # speech_metadata.style — turn-level delivery, e.g. "warm and enthusiastic"
    "audio_format": "l16",   # wav | l16 | mulaw | alaw  (what we ask the API for)
    "sample_rate": 24000,    # 24000 | 16000 | 8000
    "speed": 1.0,            # applied locally with ffmpeg atempo (the API has no rate parameter)
    "timeout": 120,
    "retries": 2,
    "voice_catalog_limit": 0,  # 0 = no cap in list_voices()
}

_CONTAINER_ARGS = {
    "mp3": ["-codec:a", "libmp3lame", "-b:a", "128k"],
    "ogg": ["-codec:a", "libopus", "-b:a", "48k", "-vbr", "on"],
    "opus": ["-codec:a", "libopus", "-b:a", "48k", "-vbr", "on"],
    "flac": ["-codec:a", "flac"],
    "wav": ["-codec:a", "pcm_s16le"],
}

# Ogg-backed containers are written to a .ogg path on purpose: Hermes' final
# voice-bubble pass short-circuits on ".ogg", so the audio is encoded once here
# instead of once here and once more by ffmpeg downstream.
_OGG_FAMILY = frozenset({"ogg", "opus"})

_G711_INPUT = {"mulaw": ["-f", "mulaw"], "alaw": ["-f", "alaw"]}


def parse_mime(mime: str) -> tuple[str, Optional[int], Optional[int]]:
    """Split "audio/l16; rate=24000; channels=1" -> ("audio/l16", 24000, 1).

    The API overrides the requested encoding's parameters (mu-law comes back at
    8000 Hz even when 24000 was asked for), so the *reported* rate must drive
    decoding or the audio plays at the wrong pitch.
    """
    base, _, params = (mime or "").partition(";")
    rate = channels = None
    for chunk in params.split(";"):
        key, _, value = chunk.strip().partition("=")
        key, value = key.strip().lower(), value.strip()
        if not value:
            continue
        try:
            if key == "rate":
                rate = int(value)
            elif key == "channels":
                channels = int(value)
        except ValueError:
            continue
    return base.strip().lower(), rate, channels


def _profile_home() -> Path:
    return Path(os.environ.get("HERMES_HOME") or (Path.home() / ".hermes"))


def _load_config_section() -> dict[str, Any]:
    """``tts.providers.gemini-custom``, freshest read each call."""
    try:
        from hermes_cli.config import load_config_readonly

        config = load_config_readonly() or {}
    except Exception:  # health: config loading must never break speech
        return {}
    tts = config.get("tts") if isinstance(config, dict) else None
    if not isinstance(tts, dict):
        return {}
    providers = tts.get("providers")
    section = providers.get(CONFIG_KEY) if isinstance(providers, dict) else None
    return section if isinstance(section, dict) else {}


def resolve_settings(**kwargs: Any) -> dict[str, Any]:
    """Order: ``DEFAULTS < config.yaml section < per-call kwargs``.

    Per-call ``voice``/``model``/``speed``/``style`` beat the static config: that
    is how a ``/voice`` pick and ``tools/render.py`` flags reach the request.
    Everything else comes from ``tts.providers.gemini-custom``.
    """
    settings = dict(DEFAULTS)
    settings.update({k: v for k, v in _load_config_section().items()
                     if k not in ("type", "command")})
    for key in ("voice", "model", "speed", "style"):
        if kwargs.get(key) is not None:
            settings[key] = kwargs[key]
    return settings


def _wrap_pcm_wav(pcm: bytes, *, sample_rate: int, channels: int = 1, width: int = 2) -> bytes:
    block_align = channels * width
    fmt = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, channels, sample_rate,
                      sample_rate * block_align, block_align, width * 8)
    data = struct.pack("<4sI", b"data", len(pcm))
    riff = struct.pack("<4sI4s", b"RIFF", 4 + len(fmt) + len(data) + len(pcm), b"WAVE")
    return riff + fmt + data + pcm


def _ogg_path(output_path: str) -> str:
    """Path to write an Ogg-backed container to: ``.ogg``, so Hermes skips its own
    transcode (``_finalize_voice_delivery`` short-circuits on that suffix)."""
    path = Path(output_path).expanduser()
    return str(path) if str(path).lower().endswith(".ogg") else str(path.with_suffix(".ogg"))


def _atempo_chain(speed: float) -> list[str]:
    """ffmpeg atempo accepts 0.5–2.0 per instance; chain for extremes."""
    filters, remaining = [], float(speed)
    while remaining > 2.0:
        filters.append("atempo=2.0000")
        remaining /= 2.0
    while remaining < 0.5:
        filters.append("atempo=0.5000")
        remaining /= 0.5
    if abs(remaining - 1.0) > 1e-3:
        filters.append(f"atempo={remaining:.4f}")
    return filters


class GeminiCustomTTS(TTSProvider):
    """Gemini 3.x TTS with speech_metadata, inline tags, formats and PCM streaming."""

    streams_pcm = True

    def __init__(self) -> None:
        self._voices_cache: Optional[list[dict[str, Any]]] = None

    # ---- identity ---------------------------------------------------------
    @property
    def name(self) -> str:
        return CONFIG_KEY

    @property
    def display_name(self) -> str:
        return "Gemini (custom / interactions API)"

    @property
    def stream_sample_rate(self) -> Optional[int]:  # read fresh: the setting may change at runtime
        try:
            return int(resolve_settings().get("sample_rate") or 24000)
        except (TypeError, ValueError):
            return 24000

    @property
    def voice_compatible(self) -> bool:
        """Opus/ogg output is what voice bubbles need — let the gateway convert."""
        return True

    def get_setup_schema(self) -> dict[str, Any]:
        return {"name": self.display_name, "badge": "gemini", "tag": "3.8 TTS",
                "env_vars": [{"key": "GEMINI_API_KEY",
                              "prompt": "Google AI Studio API key",
                              "url": "https://aistudio.google.com/app/apikey"}]}

    def is_available(self) -> bool:
        return bool(api.resolve_api_key())

    # ---- catalogues -------------------------------------------------------
    def list_models(self) -> list[dict[str, Any]]:
        return [{"id": model, "display": label} for model, label in api.TTS_MODELS.items()]

    def default_model(self) -> Optional[str]:
        return DEFAULTS["model"]

    def default_voice(self) -> Optional[str]:
        hero = str(resolve_settings().get("voice") or "").strip()
        return None if hero.lower() == "auto" else (hero or "Kore")

    def list_voices(self) -> list[dict[str, Any]]:
        """Catalogue from GET /v1beta/voices (cached 24 h); never raises."""
        if self._voices_cache is None:
            key = api.resolve_api_key()
            if not key:
                return []
            cache = _profile_home() / "cache" / "gemini_voices.json"
            try:
                self._voices_cache = api.list_voice_catalog(api_key=key, cache_path=cache)
            except Exception:  # health: a catalogue miss must not break speech
                return []
        voices = [
            {"id": v.get("id"), "display": v.get("display_name") or v.get("id"),
             "language": v.get("language_code"), "gender": v.get("gender"),
             "accent": v.get("accent"), "persona": v.get("persona")}
            for v in self._voices_cache if v.get("id")
        ]
        limit = resolve_settings().get("voice_catalog_limit") or 0
        try:
            limit = int(limit)
        except (TypeError, ValueError):
            limit = 0
        return voices[:limit] if limit > 0 else voices

    # ---- internals --------------------------------------------------------
    def _pick_voice(self, settings: dict[str, Any]) -> str:
        voice = str(settings.get("voice") or "").strip()
        if voice and voice.lower() != "auto":
            return voice
        language = str(settings.get("language") or "").strip().lower()
        if language:
            for entry in self.list_voices():
                if str(entry.get("language") or "").lower() == language:
                    return str(entry["id"])
        return "Kore"

    def _container_for(self, requested: str) -> str:
        """The caller's ``format``, clamped to the containers we can actually write."""
        fmt = str(requested or "mp3").lower().strip().lstrip(".")
        return fmt if fmt in _CONTAINER_ARGS else "mp3"

    def _write_audio(self, raw: bytes, mime: str, output_path: str, container: str,
                     sample_rate: int, speed: float) -> str:
        """Turn the API payload into *container* at *output_path* (handles wav/l16/mulaw/alaw)."""
        out = Path(output_path).expanduser()
        base_mime, reported_rate, reported_channels = parse_mime(mime)
        rate = reported_rate or sample_rate
        channels = reported_channels or 1
        if container == "wav" and base_mime == "audio/wav" and abs(speed - 1.0) < 1e-3:
            out.write_bytes(raw)  # already a WAV, nothing to re-encode
            return str(out)

        out.parent.mkdir(parents=True, exist_ok=True)
        tmp_dir = Path(tempfile.mkdtemp(prefix="gemini-tts-"))
        try:
            if base_mime == "audio/wav":
                source = tmp_dir / "in.wav"
                source.write_bytes(raw)
                input_args = ["-f", "wav"]
            elif base_mime in ("audio/mulaw", "audio/alaw"):
                codec = "mulaw" if base_mime == "audio/mulaw" else "alaw"
                source = tmp_dir / f"in.{codec}"
                source.write_bytes(raw)
                input_args = [*_G711_INPUT[codec], "-ar", str(rate), "-ac", str(channels)]
            else:  # audio/l16 and anything else raw PCM
                source = tmp_dir / "in.pcm"
                source.write_bytes(raw)
                input_args = ["-f", "s16le", "-ar", str(rate), "-ac", str(channels)]

            ffmpeg = shutil.which("ffmpeg")
            if not ffmpeg:
                if container == "wav":
                    out.write_bytes(_wrap_pcm_wav(raw, sample_rate=rate, channels=channels))
                    return str(out)
                raise RuntimeError("ffmpeg not found; cannot produce " + container)

            filters = _atempo_chain(speed) if abs(speed - 1.0) > 1e-3 else []
            cmd = [ffmpeg, "-y", "-loglevel", "error", *input_args, "-i", str(source)]
            if filters:
                cmd += ["-filter:a", ",".join(filters)]
            cmd += [*_CONTAINER_ARGS[container], str(out)]
            result = subprocess.run(cmd, capture_output=True)
            if result.returncode != 0 or not out.exists() or out.stat().st_size == 0:
                raise RuntimeError("ffmpeg conversion failed: "
                                   + result.stderr.decode("utf-8", "replace")[:300])
            return str(out)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    def _log_usage(self, settings: dict[str, Any], usage: dict[str, Any], chars: int) -> None:
        try:
            record = {"ts": _now_iso(), "model": settings.get("model"), "voice": settings.get("voice"),
                      "chars": chars, "input_tokens": usage.get("total_input_tokens"),
                      "output_tokens": usage.get("total_output_tokens"),
                      "audio_tokens": next((m.get("tokens") for m in
                                            (usage.get("output_tokens_by_modality") or [])
                                            if m.get("modality") == "audio"), None)}
            path = _profile_home() / "gemini-tts-usage.jsonl"
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(record, ensure_ascii=False) + "\n")
        except OSError:
            pass

    # ---- TTSProvider API --------------------------------------------------
    def synthesize(self, text: str, output_path: str, *, voice: Optional[str] = None,
                   model: Optional[str] = None, speed: Optional[float] = None,
                   format: str = "mp3", **extra: Any) -> str:
        settings = resolve_settings(voice=voice, model=model, speed=speed,
                                    style=extra.get("style"))
        mime = api.MIME_BY_FORMAT.get(str(settings.get("audio_format") or "l16").lower(), "audio/l16")
        try:
            sample_rate = int(settings.get("sample_rate") or 24000)
        except (TypeError, ValueError):
            sample_rate = 24000
        payload = api.build_payload(
            model=str(settings.get("model") or DEFAULTS["model"]), text=text,
            voice=self._pick_voice(settings), style=str(settings.get("style") or ""),
            mime_type=mime, sample_rate=sample_rate)
        key = api.resolve_api_key()
        if not key:
            raise RuntimeError("gemini-custom: no GEMINI_API_KEY / GOOGLE_API_KEY available")
        raw, reported_mime, usage = api.synthesize_request(
            payload, api_key=key, timeout=float(settings.get("timeout") or 120),
            retries=int(settings.get("retries") or 0))
        container = self._container_for(format)
        target = _ogg_path(output_path) if container in _OGG_FAMILY else output_path
        written = self._write_audio(raw, reported_mime or mime, target, container,
                                    sample_rate, float(settings.get("speed") or 1.0))
        self._log_usage(settings, usage, len(text))
        return written

    def stream(self, text: str, *, voice: Optional[str] = None, model: Optional[str] = None,
               format: str = "opus", **extra: Any) -> Iterator[bytes]:
        """Yield raw 24 kHz mono int16 PCM (Hermes' live voice path consumes PCM)."""
        settings = resolve_settings(voice=voice, model=model, style=extra.get("style"))
        payload = api.build_payload(
            model=str(settings.get("model") or DEFAULTS["model"]), text=text,
            voice=self._pick_voice(settings), style=str(settings.get("style") or ""),
            mime_type="audio/l16", sample_rate=int(settings.get("sample_rate") or 24000), stream=True)
        key = api.resolve_api_key()
        if not key:
            raise RuntimeError("gemini-custom: no GEMINI_API_KEY / GOOGLE_API_KEY available")
        yield from api.stream_request(payload, api_key=key,
                                      timeout=float(settings.get("timeout") or 120),
                                      retries=int(settings.get("retries") or 0))


def _now_iso() -> str:
    import datetime

    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")
