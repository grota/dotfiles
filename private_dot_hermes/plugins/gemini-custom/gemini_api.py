"""HTTP layer for the Gemini TTS ``interactions`` API.

Everything here is verified against the live API (free tier, Nov 2026):

* ``POST /v1beta/interactions`` — unary TTS. ``generation_config.speech_config``
  is a *list* ``[{"voice": ...}]`` for one speaker; a two-speaker dialogue would
  use an *object* ``{"speakers": [...]}``, which this provider does not send.
* The audio lands in ``steps[*].content[*]`` as ``{"type": "audio", "data": b64,
  "mime_type": "audio/wav" | "audio/l16" | "audio/mulaw" | "audio/alaw"}``.
  Unary defaults to WAV with a RIFF header; ``mime_type`` + ``sample_rate`` in
  ``response_format`` select another encoding.
* ``stream: true`` returns SSE events; audio arrives in ``event.delta`` with
  ``type == "audio"`` as base64 PCM chunks.
* ``GET /v1beta/voices`` — paged voice catalogue (2114 voices on this key, 1000
  per page, ``next_page_token``).
"""

from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Iterator, Optional

BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
INTERACTIONS_URL = f"{BASE_URL}/interactions"
VOICES_URL = f"{BASE_URL}/voices"

TTS_MODELS = {
    "gemini-3.8-flash-tts": "Gemini 3.8 Flash TTS (max fidelity)",
    "gemini-3.8-flash-lite-tts": "Gemini 3.8 Flash-Lite TTS (fast/cheap)",
    "gemini-3.1-flash-tts-preview": "Gemini 3.1 Flash TTS (preview, legacy PCM)",
    # The 2.5 TTS models are deliberately absent: /v1beta/interactions rejects
    # them (400 "Speech annotations are not supported for model …", and also
    # AUDIO_L16/AUDIO_WAV "not supported"). They remain usable through Hermes'
    # built-in `gemini` provider, which speaks the generateContent path.
}

MIME_BY_FORMAT = {
    "wav": "audio/wav",
    "l16": "audio/l16",
    "mulaw": "audio/mulaw",
    "alaw": "audio/alaw",
}


class GeminiTTSError(RuntimeError):
    """Any failure talking to the Gemini TTS API (message is user-facing).

    ``status`` and ``body`` are kept so the caller can tell a per-minute rate
    limit from an exhausted daily budget without parsing the message.
    """

    def __init__(self, message: str, *, status: Optional[int] = None, body: str = "") -> None:
        super().__init__(message)
        self.status = status
        self.body = body


def is_quota_error(exc: BaseException) -> bool:
    """True for 429 / RESOURCE_EXHAUSTED: the model has no budget right now."""
    status = getattr(exc, "status", None)
    body = (getattr(exc, "body", "") or "") + " " + str(exc)
    return status == 429 or "RESOURCE_EXHAUSTED" in body or "quota" in body.lower()


def is_daily_quota_error(exc: BaseException) -> bool:
    """True when the 429 is the *daily* cap (so it must stay marked until reset)."""
    body = (getattr(exc, "body", "") or "") + " " + str(exc)
    lowered = body.lower()
    return "perday" in lowered or "per day" in lowered or "perdayperproject" in lowered


def next_quota_reset_iso() -> str:
    """Next midnight Pacific (Google's daily quota boundary), as ISO-8601 UTC."""
    try:
        from datetime import datetime, time as dtime, timedelta
        from zoneinfo import ZoneInfo

        tz = ZoneInfo("America/Los_Angeles")
        now = datetime.now(tz)
        reset = datetime.combine(now.date() + timedelta(days=1), dtime(0, 0), tzinfo=tz)
        return reset.astimezone(ZoneInfo("UTC")).isoformat(timespec="seconds")
    except Exception:  # tz database missing: fall back to +24h
        import datetime as _dt

        return (_dt.datetime.now(_dt.timezone.utc) + _dt.timedelta(hours=24)).isoformat(timespec="seconds")


def _quota_state_path() -> Path:
    return _hermes_home() / "cache" / "gemini-model-quota.json"


def load_quota_state() -> dict[str, Any]:
    """``{model: {"exhausted_until": iso, "reason": str}}``; stale entries pruned."""
    import datetime as _dt

    try:
        data = json.loads(_quota_state_path().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    now = _dt.datetime.now(_dt.timezone.utc)
    fresh: dict[str, Any] = {}
    for model, entry in data.items():
        if not isinstance(entry, dict):
            continue
        try:
            until = _dt.datetime.fromisoformat(str(entry.get("exhausted_until")))
        except ValueError:
            continue
        if until > now:
            fresh[model] = entry
    return fresh


def model_is_exhausted(model: str) -> bool:
    return model in load_quota_state()


def mark_model_exhausted(model: str, *, daily: bool, reason: str = "") -> None:
    """Persist exhaustion so other processes skip the model too.

    A per-minute limit is deliberately *not* persisted: it clears in a minute,
    and writing it down would cost the model its whole day.
    """
    if not daily:
        return
    state = load_quota_state()
    state[model] = {"exhausted_until": next_quota_reset_iso(), "reason": reason[:300],
                    "marked_at": _now_utc_iso()}
    path = _quota_state_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(state, indent=1, sort_keys=True), encoding="utf-8")
    except OSError:
        pass


def clear_quota_state(model: Optional[str] = None) -> None:
    """Forget exhaustion (all models, or one) — for tests and manual recovery."""
    if model is None:
        state = {}
    else:
        state = load_quota_state()
        state.pop(model, None)
    path = _quota_state_path()
    try:
        if state:
            path.write_text(json.dumps(state, indent=1, sort_keys=True), encoding="utf-8")
        elif path.exists():
            path.unlink()
    except OSError:
        pass


def _now_utc_iso() -> str:
    import datetime as _dt

    return _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="seconds")


class ChunkCapContractError(RuntimeError):
    """Hermes' chunk-cap table is missing or no longer behaves as this plugin needs.

    Deliberately loud: the alternative is splitting long replies at an arbitrary
    4000 characters while everything looks fine. See ``install_chunk_cap``.
    """


def _hermes_home() -> Path:
    return Path(os.environ.get("HERMES_HOME") or (Path.home() / ".hermes"))


KEY_ENV_NAMES = ("GOOGLE_GENERATIVE_AI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY")


def _clean(value: str) -> str:
    return (value or "").strip().strip('"').strip("'")


def candidate_api_keys() -> list[str]:
    """Distinct usable keys, best guess first: env, then the profile dotenv.

    More than one name can be set and they are not necessarily equivalent — on
    this install ``GEMINI_API_KEY`` is a ``${...}`` reference that may expand to
    something the API rejects, while ``GOOGLE_GENERATIVE_AI_API_KEY`` (the name
    Google's SDKs use) works. So the caller tries them in order rather than
    trusting the first hit.
    """
    found: list[str] = []

    def add(value: str) -> None:
        value = _clean(value)
        if value and "$" not in value and value not in found:
            found.append(value)

    for name in KEY_ENV_NAMES:
        add(os.environ.get(name) or "")
    dotenv = _hermes_home() / ".env"
    try:
        for line in dotenv.read_text(encoding="utf-8", errors="replace").splitlines():
            name, sep, value = line.strip().partition("=")
            if sep and name in KEY_ENV_NAMES:
                add(value)
    except OSError:
        pass
    return found


def resolve_api_key() -> Optional[str]:
    """First candidate key, or ``None``."""
    keys = candidate_api_keys()
    return keys[0] if keys else None


def _post(url: str, payload: dict[str, Any], *, timeout: float, retries: int,
          stream: bool = False, api_key: str) -> Any:
    """POST JSON; retries 429/5xx with backoff. Returns parsed JSON, or the open response for stream."""
    body = json.dumps(payload).encode()
    last_error = ""
    for attempt in range(max(0, retries) + 1):
        request = urllib.request.Request(
            url, data=body,
            headers={"Content-Type": "application/json", "x-goog-api-key": api_key})
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                if stream:
                    return response.read().decode("utf-8", "replace")
                return json.load(response)
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")
            last_error = f"HTTP {exc.code}: {detail[:400]}"
            retryable = exc.code == 429 or 500 <= exc.code < 600
            if not retryable or attempt >= retries:
                raise GeminiTTSError(f"Gemini TTS {last_error}", status=exc.code,
                                     body=detail[:8000]) from exc
            delay = 5.0 * (attempt + 1)
            header = exc.headers.get("Retry-After") if exc.headers else None
            if header:
                try:
                    delay = min(60.0, max(1.0, float(header)))
                except ValueError:
                    pass
            time.sleep(delay)
        except urllib.error.URLError as exc:
            last_error = f"network error: {exc.reason}"
            if attempt >= retries:
                raise GeminiTTSError(f"Gemini TTS {last_error}") from exc
            time.sleep(2.0 * (attempt + 1))
    raise GeminiTTSError(f"Gemini TTS {last_error or 'failed'}")


def build_payload(
    *, model: str, text: str, voice: str, style: str = "",
    mime_type: str = "audio/l16", sample_rate: Optional[int] = None, stream: bool = False,
) -> dict[str, Any]:
    """Assemble one single-speaker interactions request.

    The transcript is one ``text`` part; ``style`` rides in a ``speech_metadata``
    annotation because Gemini 3.8 reads the part itself verbatim. Multi-speaker
    requests (``speech_config.speakers``, exactly two) are deliberately not
    supported by this provider — see ``provider.py``.
    """
    part: dict[str, Any] = {"type": "text", "text": text}
    if style:
        part["annotations"] = [{"type": "speech_metadata", "style": style}]

    response_format: dict[str, Any] = {"type": "audio", "mime_type": mime_type}
    if sample_rate:
        response_format["sample_rate"] = int(sample_rate)

    payload: dict[str, Any] = {
        "model": model,
        "input": [{"type": "user_input", "content": [part]}],
        "response_format": response_format,
        "generation_config": {"speech_config": [{"voice": voice}]},
    }
    if stream:
        payload["stream"] = True
    return payload


def synthesize_request(payload: dict[str, Any], *, api_key: str, timeout: float,
                       retries: int) -> tuple[bytes, str, dict[str, Any]]:
    """Unary synth. Returns (audio_bytes, mime_type, usage)."""
    data = _post(INTERACTIONS_URL, payload, timeout=timeout, retries=retries, api_key=api_key)
    status = data.get("status")
    if status and status != "completed":
        raise GeminiTTSError(f"Gemini TTS interaction ended with status '{status}'")
    for step in data.get("steps") or []:
        for part in step.get("content") or []:
            if isinstance(part, dict) and part.get("type") == "audio" and part.get("data"):
                raw = base64.b64decode(part["data"])
                if not raw:
                    raise GeminiTTSError("Gemini TTS returned an empty audio payload")
                return raw, str(part.get("mime_type") or ""), dict(data.get("usage") or {})
    raise GeminiTTSError("Gemini TTS response contained no audio part")


def stream_payload(payload: dict[str, Any], *, api_key: str, timeout: float,
                   retries: int) -> str:
    """POST a ``stream: true`` interaction and return the raw SSE text."""
    return _post(INTERACTIONS_URL, payload, timeout=timeout, retries=retries,
                 stream=True, api_key=api_key)


def iter_stream_audio(text: str) -> Iterator[bytes]:
    """Yield the audio payloads of an SSE interaction body."""
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        chunk = line[len("data:"):].strip()
        if not chunk or chunk == "[DONE]":
            continue
        try:
            event = json.loads(chunk)
        except ValueError:
            continue
        delta = event.get("delta") or {}
        if isinstance(delta, dict) and delta.get("type") == "audio" and delta.get("data"):
            audio = base64.b64decode(delta["data"])
            if audio:
                yield audio
        elif event.get("event_type") == "error" or event.get("error"):
            raise GeminiTTSError(f"Gemini TTS stream error: {str(event.get('error') or event)[:300]}")


def stream_request(payload: dict[str, Any], *, api_key: str, timeout: float,
                   retries: int) -> Iterator[bytes]:
    """Yield raw audio chunks from an SSE ``stream: true`` interaction."""
    yield from iter_stream_audio(stream_payload(payload, api_key=api_key,
                                                timeout=timeout, retries=retries))


def list_voice_catalog(*, api_key: str, cache_path: Path, ttl_seconds: int = 86400,
                       timeout: float = 30.0) -> list[dict[str, Any]]:
    """Full voice catalogue, cached on disk (the endpoint pages at 1000)."""
    try:
        if cache_path.exists() and (time.time() - cache_path.stat().st_mtime) < ttl_seconds:
            cached = json.loads(cache_path.read_text(encoding="utf-8"))
            if isinstance(cached, list) and cached:
                return cached
    except (OSError, ValueError):
        pass

    voices: list[dict[str, Any]] = []
    token: Optional[str] = None
    while True:
        url = f"{VOICES_URL}?pageSize=1000" + (f"&pageToken={token}" if token else "")
        request = urllib.request.Request(url, headers={"x-goog-api-key": api_key})
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                page = json.load(response)
        except (urllib.error.HTTPError, urllib.error.URLError, ValueError) as exc:
            raise GeminiTTSError(f"Gemini voice catalogue unavailable: {exc}") from exc
        voices.extend(page.get("voices") or [])
        token = page.get("next_page_token")
        if not token:
            break
    try:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(voices), encoding="utf-8")
    except OSError:
        pass
    return voices


# --- chunk cap: the number Hermes needs before it ever calls us ------------
#
# Hermes splits a long reply *before* dispatching to a provider and takes the
# per-request cap from ``tools.tts_tool_delivery.PROVIDER_MAX_TEXT_LENGTH`` — a
# plain dict of provider -> characters, falling back to 4000 for a name it does
# not know. That table is importable at plugin-registration time, which is
# earlier than the first reply, so a plugin can publish its cap there and the
# user never has to put ``max_text_length`` in config.yaml (and never sees the
# "not a recognized config key" warning that a flat ``tts.<name>`` key earns).
#
# The number itself comes from the model card, verified live via
# ``GET /v1beta/models/{model}`` -> ``inputTokenLimit`` (8192 on every 3.8/3.1/2.5
# TTS model). One metadata request per model per 30 days; a synthesis call is
# never made for this, so the 10-a-day TTS quota is untouched.

CHARS_PER_TOKEN_FLOOR = 2.0   # dense text (numbers, code, short words) can reach this
FALLBACK_INPUT_TOKENS = 8192  # the documented window; used only if introspection is unavailable
LIMITS_TTL_SECONDS = 30 * 86400

_table: dict[str, int] = {}   # provider -> cap we published (so we can refresh our own entry)


def _limits_cache_path() -> Path:
    return _hermes_home() / "cache" / "gemini_model_limits.json"


def _configured_model() -> str:
    """First of ``tts.providers.gemini-custom.models`` (or the plugin default)."""
    try:
        from hermes_cli.config import load_config_readonly

        tts = (load_config_readonly() or {}).get("tts") or {}
        section = (tts.get("providers") or {}).get("gemini-custom") or {}
        models = section.get("models")
        if isinstance(models, list):
            for entry in models:
                model = str(entry or "").strip()
                if model:
                    return model
    except Exception:
        pass
    return "gemini-3.8-flash-tts"


def model_limits(model: str, *, allow_network: bool = True, timeout: float = 10.0,
                 ttl_seconds: int = LIMITS_TTL_SECONDS) -> dict[str, Any]:
    """Cached ``GET /v1beta/models/{model}`` metadata; ``{}`` when unavailable.

    Fail-soft on purpose: the cap must never be the reason a reply stays silent.
    """
    cache_path = _limits_cache_path()
    cache: dict[str, Any] = {}
    try:
        loaded = json.loads(cache_path.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            cache = loaded
    except (OSError, ValueError):
        cache = {}

    entry = cache.get(model)
    if isinstance(entry, dict) and (time.time() - float(entry.get("checked_at") or 0)) < ttl_seconds:
        return entry

    if not allow_network:
        return entry if isinstance(entry, dict) else {}

    key = resolve_api_key()
    if not key:
        return entry if isinstance(entry, dict) else {}
    request = urllib.request.Request(f"{BASE_URL}/models/{model}", headers={"x-goog-api-key": key})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            data = json.load(response)
    except (urllib.error.HTTPError, urllib.error.URLError, ValueError, OSError):
        return entry if isinstance(entry, dict) else {}
    entry = {"inputTokenLimit": data.get("inputTokenLimit"),
             "outputTokenLimit": data.get("outputTokenLimit"),
             "checked_at": int(time.time())}
    if isinstance(entry["inputTokenLimit"], int):
        cache[model] = entry
        try:
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(json.dumps(cache, indent=1), encoding="utf-8")
        except OSError:
            pass
    return entry


def chunk_cap_for(model: Optional[str] = None, *, allow_network: bool = True) -> int:
    """Character cap implied by the model's input window, rounded down to 1000."""
    model = model or _configured_model()
    limits = model_limits(model, allow_network=allow_network)
    tokens = limits.get("inputTokenLimit")
    if not isinstance(tokens, int) or tokens <= 0:
        tokens = FALLBACK_INPUT_TOKENS
    return max(1000, int(tokens * CHARS_PER_TOKEN_FLOOR) // 1000 * 1000)


def _provider_table() -> dict[str, int]:
    """Hermes' provider→cap table, or a loud ``ChunkCapContractError``.

    This is an internal data structure, not a documented extension point. If it
    moves or is renamed, saying nothing would silently split long replies at
    Hermes' 4000-character fallback; failing here surfaces it in
    ``hermes plugins doctor``, in the gateway log, and in every reply.
    """
    try:
        from tools.tts_tool_delivery import PROVIDER_MAX_TEXT_LENGTH
    except Exception as exc:
        raise ChunkCapContractError(
            "gemini-custom: Hermes' chunk-cap table is gone "
            "(tools.tts_tool_delivery.PROVIDER_MAX_TEXT_LENGTH). Without it the "
            "plugin cannot publish its per-request cap and long replies would be "
            "split at 4000 characters. Fix the import path or pin the cap in "
            "Hermes itself.") from exc
    if not isinstance(PROVIDER_MAX_TEXT_LENGTH, dict):
        raise ChunkCapContractError(
            "gemini-custom: tools.tts_tool_delivery.PROVIDER_MAX_TEXT_LENGTH is "
            f"{type(PROVIDER_MAX_TEXT_LENGTH).__name__}, expected a dict.")
    return PROVIDER_MAX_TEXT_LENGTH


def _resolve_via_hermes(name: str, cap: int) -> int:
    """What Hermes' own resolver returns for *name* with an empty config."""
    from tools.tts_tool_delivery import _resolve_max_text_length

    return int(_resolve_max_text_length(name, {}))


def _config_override(name: str) -> Optional[int]:
    """``tts.<name>.max_text_length`` if the user pinned one (it outranks us)."""
    try:
        from hermes_cli.config import load_config_readonly

        tts = (load_config_readonly() or {}).get("tts") or {}
        section = tts.get(name) if isinstance(tts, dict) else None
        value = section.get("max_text_length") if isinstance(section, dict) else None
        return int(value) if isinstance(value, int) and value > 0 else None
    except Exception:
        return None


def _check_contract(name: str, cap: int) -> None:
    """Round-trip through Hermes' resolver; raises ``ChunkCapContractError``."""
    if _config_override(name):
        return  # an explicit config value is the user's call, not a broken contract
    resolved = _resolve_via_hermes(name, cap)
    if resolved != cap:
        raise ChunkCapContractError(
            "gemini-custom: published max_text_length=%d for '%s' but Hermes "
            "resolves %s. Its chunk-cap contract changed — see "
            "tools/tts_tool_delivery._resolve_max_text_length." % (cap, name, resolved))


def install_chunk_cap(name: str = "gemini-custom", *, allow_network: bool = False,
                      strict: bool = False) -> Optional[int]:
    """Publish the cap into Hermes' provider table; returns what Hermes will use.

    Idempotent and non-destructive: an entry we did not write (upstream's, or a
    config override) is left alone. With ``strict=True`` (plugin registration) a
    broken contract raises :class:`ChunkCapContractError`; otherwise it is logged
    and the previous behaviour is kept — the hook must never break a turn.
    """
    try:
        table = _provider_table()
        cap = chunk_cap_for(allow_network=allow_network)
        current = table.get(name)
        if current is not None and current != _table.get(name):
            return current  # somebody else owns the entry; don't fight it
        table[name] = cap
        _table[name] = cap
        _check_contract(name, cap)
        return cap
    except ChunkCapContractError as exc:
        if strict:
            raise
        import logging

        logging.getLogger(__name__).error("%s", exc)
        return None


def chunk_cap_status(name: str = "gemini-custom") -> tuple[bool, str]:
    """``(ok, detail)`` — cheap contract probe for the synthesize path."""
    try:
        table = _provider_table()
    except ChunkCapContractError as exc:
        return False, str(exc)
    cap = table.get(name)
    if not isinstance(cap, int) or cap <= 0:
        return False, (f"gemini-custom: no chunk cap published for '{name}'; Hermes "
                       "would split replies at 4000 characters.")
    if _config_override(name):
        return True, "config override"
    try:
        _check_contract(name, cap)
    except ChunkCapContractError as exc:
        _table.pop(name, None)   # force a re-publish attempt on the next call
        return False, str(exc)
    return True, "ok"


def require_chunk_cap_contract(name: str = "gemini-custom") -> None:
    """Raise ``ChunkCapContractError`` unless Hermes will honour our cap.

    Called from ``synthesize``/``stream``: a broken contract must fail the reply
    loudly, not quietly chunk at 4000 characters.
    """
    ok, detail = chunk_cap_status(name)
    if not ok:
        raise ChunkCapContractError(detail)


def refresh_chunk_cap(**_kwargs: Any) -> None:
    """``pre_llm_call`` hook body: one metadata request per model per 30 days.

    Hook failures must never touch the turn, so everything is swallowed (and a
    contract problem is logged by ``install_chunk_cap`` itself).
    """
    try:
        install_chunk_cap(allow_network=True)
    except Exception:
        return

