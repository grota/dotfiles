#!/usr/bin/env python3
"""Offline self-test for the gemini-custom provider (no API calls, no pytest needed).

    cd ~/.hermes/hermes-agent && python3 ~/.hermes/plugins/gemini-custom/tests/selftest.py

Run it with a python that can import ``agent.tts_provider`` (the Hermes venv).
"""

from __future__ import annotations

import base64
import importlib.util
import json
import math
import os
import struct
import subprocess
import sys
import tempfile
import types
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parent.parent
HERMES = Path.home() / ".hermes" / "hermes-agent"
if str(HERMES) not in sys.path:
    sys.path.insert(0, str(HERMES))

# import the plugin package under a valid module name (dir name has a hyphen)
pkg = types.ModuleType("gemini_custom")
pkg.__path__ = [str(PLUGIN_DIR)]
sys.modules["gemini_custom"] = pkg
spec = importlib.util.spec_from_file_location("gemini_custom.provider", PLUGIN_DIR / "provider.py")
provider = importlib.util.module_from_spec(spec)
sys.modules["gemini_custom.provider"] = provider
spec.loader.exec_module(provider)

spec_api = importlib.util.spec_from_file_location("gemini_custom.gemini_api", PLUGIN_DIR / "gemini_api.py")
api = importlib.util.module_from_spec(spec_api)
sys.modules["gemini_custom.gemini_api"] = api
spec_api.loader.exec_module(api)
provider.api = api

FAILED: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"PASS {name}")
    else:
        print(f"FAIL {name} {detail}")
        FAILED.append(name)


def tone(seconds: float, rate: int = 24000, freq: float = 440.0) -> bytes:
    n = int(seconds * rate)
    return struct.pack(f"<{n}h", *(int(12000 * math.sin(2 * math.pi * freq * i / rate)) for i in range(n)))


def duration_of(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "csv=p=0", str(path)], capture_output=True, text=True)
    return float(out.stdout.strip() or 0)


tmp = Path(tempfile.mkdtemp(prefix="gemini-custom-test-"))

# ---- mime parsing ---------------------------------------------------------
check("parse_mime l16", provider.parse_mime("audio/l16; rate=24000; channels=1") == ("audio/l16", 24000, 1))
check("parse_mime mulaw 8k", provider.parse_mime("audio/mulaw; rate=8000; channels=1")[:2] == ("audio/mulaw", 8000))
check("parse_mime bare", provider.parse_mime("audio/wav") == ("audio/wav", None, None))

# ---- atempo chain ---------------------------------------------------------
check("atempo 1.0", provider._atempo_chain(1.0) == [])
check("atempo 1.5", provider._atempo_chain(1.5) == ["atempo=1.5000"])
check("atempo 4.0", provider._atempo_chain(4.0) == ["atempo=2.0000", "atempo=2.0000"])
check("atempo 0.25", provider._atempo_chain(0.25) == ["atempo=0.5000", "atempo=0.5000"])

# ---- payload shape -------------------------------------------------------
single = api.build_payload(model="m", text="hola", voice="Kore", style="warm",
                           mime_type="audio/l16", sample_rate=24000)
check("payload single speech_config is list", single["generation_config"]["speech_config"] == [{"voice": "Kore"}])
check("payload annotations", single["input"][0]["content"][0]["annotations"] ==
      [{"type": "speech_metadata", "style": "warm"}])
check("payload response_format", single["response_format"] ==
      {"type": "audio", "mime_type": "audio/l16", "sample_rate": 24000})
check("payload no stream flag", "stream" not in single)
check("payload one text part", len(single["input"][0]["content"]) == 1)

plain = api.build_payload(model="m", text="hola", voice="Kore")
check("payload no annotations without style", "annotations" not in plain["input"][0]["content"][0])
check("payload no sample_rate when unset", plain["response_format"] == {"type": "audio", "mime_type": "audio/l16"})

# ---- media conversion ----------------------------------------------------
inst = provider.GeminiCustomTTS()
pcm = tone(1.0)

wav_out = inst._write_audio(pcm, "audio/l16; rate=24000; channels=1", str(tmp / "a.wav"), "wav", 24000, 1.0)
wav_path = Path(wav_out)
wav_bytes = wav_path.read_bytes()
head = wav_bytes[:12]


def data_offset(buf: bytes) -> int:
    """Walk RIFF chunks: ffmpeg writes a LIST/metadata chunk before data."""
    pos = 12
    while pos + 8 <= len(buf):
        cid = buf[pos:pos + 4]
        size = struct.unpack("<I", buf[pos + 4:pos + 8])[0]
        if cid == b"data":
            return pos + 8
        pos += 8 + size + (size & 1)
    return 44


first = struct.unpack("<h", wav_bytes[data_offset(wav_bytes):data_offset(wav_bytes) + 2])[0]
check("l16->wav header", head[:4] == b"RIFF" and head[8:12] == b"WAVE", head)
check("l16->wav duration", abs(duration_of(wav_path) - 1.0) < 0.05, f"{duration_of(wav_path):.3f}s")
check("l16->wav no header-as-PCM", abs(first) < 12000 * 0.6,
      f"first sample {first} at offset {data_offset(wav_bytes)}")

mp3 = inst._write_audio(pcm, "audio/l16; rate=24000; channels=1", str(tmp / "a.mp3"), "mp3", 24000, 1.0)
check("l16->mp3 duration", abs(duration_of(Path(mp3)) - 1.0) < 0.1, f"{duration_of(Path(mp3)):.3f}s")

ogg = inst._write_audio(pcm, "audio/l16; rate=24000; channels=1", str(tmp / "a.ogg"), "ogg", 24000, 1.0)
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                        "stream=codec_name", "-of", "csv=p=0", ogg], capture_output=True, text=True)
check("l16->ogg is opus", probe.stdout.strip() == "opus", probe.stdout.strip())

fast = inst._write_audio(pcm, "audio/l16; rate=24000; channels=1", str(tmp / "fast.mp3"), "mp3", 24000, 2.0)
check("speed 2x halves duration", abs(duration_of(Path(fast)) - 0.5) < 0.1, f"{duration_of(Path(fast)):.3f}s")

# mulaw at 8 kHz must be decoded with the rate the API reported, not the config default
mulaw_raw = bytes([0xFF] * 8000 + [0x7F] * 8000)  # 2 s of silence-ish G.711
mulaw_out = inst._write_audio(mulaw_raw, "audio/mulaw; rate=8000; channels=1", str(tmp / "m.wav"),
                              "wav", 24000, 1.0)
check("mulaw uses reported 8k rate", abs(duration_of(Path(mulaw_out)) - 2.0) < 0.1,
      f"{duration_of(Path(mulaw_out)):.3f}s")

# wav passthrough must not re-encode
real_wav = Path(wav_out).read_bytes()
pass_out = inst._write_audio(real_wav, "audio/wav", str(tmp / "pass.wav"), "wav", 24000, 1.0)
check("wav passthrough byte-identical", Path(pass_out).read_bytes() == real_wav)

# ---- settings precedence -------------------------------------------------
_orig_section = provider._load_config_section
provider._load_config_section = lambda: {"model": "from-config", "voice": "voice-config"}
settings = provider.resolve_settings(model="dispatcher-model", speed=1.5, style="from-call")
check("precedence config<kwargs",
      settings["model"] == "dispatcher-model" and settings["voice"] == "voice-config"
      and settings["speed"] == 1.5 and settings["style"] == "from-call",
      json.dumps({k: settings[k] for k in ("model", "voice", "speed", "style")}))
check("precedence keeps defaults", settings["sample_rate"] == 24000 and settings["audio_format"] == "l16")
provider._load_config_section = _orig_section

check("no runtime override file left", not hasattr(provider, "_load_override_file")
      and not hasattr(provider, "OVERRIDE_FILE"))
check("no dead per-plugin knobs", not ({"multi_speaker", "output_format", "max_text_length",
                                        "inline_tags", "speaker"} & set(provider.DEFAULTS)))

# ---- container selection (format is the only input) ----------------------
check("container follows format", inst._container_for("ogg") == "ogg")
check("container default mp3", inst._container_for("") == "mp3")
check("container clamps unknown", inst._container_for("aiff") == "mp3")
check("ogg family retargets path", provider._ogg_path("/tmp/tts_1.mp3") == "/tmp/tts_1.ogg")
check("ogg path kept", provider._ogg_path("/tmp/tts_1.ogg") == "/tmp/tts_1.ogg")

# ---- Hermes chunk cap: the key must live in tts.<provider> ---------------
try:
    from tools.tts_tool_delivery import _resolve_max_text_length

    check("cap honoured at tts.<provider>",
          _resolve_max_text_length("gemini-custom", {"gemini-custom": {"max_text_length": 16000}}) == 16000)
    check("cap inert under tts.providers",
          _resolve_max_text_length("gemini-custom", {"providers": {"gemini-custom": {"max_text_length": 16000}}}) == 4000)
except ImportError:
    print("SKIP cap checks (tools.tts_tool_delivery not importable)")

# ---- SSE parsing ---------------------------------------------------------
sse = "\n".join([
    'data: {"event_type":"step.delta","delta":{"type":"audio","data":"%s"}}' % base64.b64encode(b"\x01\x02").decode(),
    'data: {"event_type":"step.delta","delta":{"type":"text","data":"x"}}',
    'data: {"event_type":"step.delta","delta":{"type":"audio","data":"%s"}}' % base64.b64encode(b"\x03\x04").decode(),
    "data: [DONE]",
])
api._post = lambda *a, **k: sse
chunks = list(api.stream_request({}, api_key="k", timeout=1, retries=0))
check("stream_request yields audio chunks", chunks == [b"\x01\x02", b"\x03\x04"], str(chunks))

# ---- identity ------------------------------------------------------------
check("name", inst.name == "gemini-custom")
check("voice_compatible", inst.voice_compatible is True)
check("streams_pcm", inst.streams_pcm is True)
check("default_voice follows config", inst.default_voice() == provider.resolve_settings()["voice"],
      f"{inst.default_voice()} vs {provider.resolve_settings()['voice']}")

# ---- chunk cap: published to Hermes' table, no config key ---------------
try:
    from tools.tts_tool_delivery import PROVIDER_MAX_TEXT_LENGTH, _resolve_max_text_length

    PROVIDER_MAX_TEXT_LENGTH.pop("gemini-custom", None)
    api._table.clear()
    published = api.install_chunk_cap(allow_network=False)
    check("cap published with no config", published == 16000, str(published))
    check("chunker sees it with an empty config",
          _resolve_max_text_length("gemini-custom", {}) == 16000)
    check("an entry we did not write is respected",
          (PROVIDER_MAX_TEXT_LENGTH.__setitem__("gemini-custom", 9999)
           or api.install_chunk_cap(allow_network=False)) == 9999
          and PROVIDER_MAX_TEXT_LENGTH["gemini-custom"] == 9999)
    PROVIDER_MAX_TEXT_LENGTH.pop("gemini-custom", None)
    api._table.clear()
except ImportError:
    print("SKIP cap-install checks (tools.tts_tool_delivery not importable)")

# introspection cache: a cached window drives the number, offline
_orig_home = os.environ.get("HERMES_HOME")
_cache_home = Path(tempfile.mkdtemp(prefix="gemini-home-"))
(_cache_home / "cache").mkdir(parents=True)
(_cache_home / "cache" / "gemini_model_limits.json").write_text(json.dumps(
    {"some-model": {"inputTokenLimit": 4096, "outputTokenLimit": 8192, "checked_at": 2 ** 31}}))
os.environ["HERMES_HOME"] = str(_cache_home)
check("cached window drives the cap", api.chunk_cap_for("some-model", allow_network=False) == 8000,
      str(api.chunk_cap_for("some-model", allow_network=False)))
check("stale model falls back to the documented window",
      api.chunk_cap_for("unknown-model", allow_network=False) == 16000)
if _orig_home is None:
    os.environ.pop("HERMES_HOME", None)
else:
    os.environ["HERMES_HOME"] = _orig_home

# ---- inline vocal tags (auxiliary task, off by default) -----------------
_orig_rewrite = provider._rewrite_tags
provider._rewrite_tags = lambda system, user, fallback: fallback.replace("Hola", "Hola <laugh>")
check("tags off by default", provider.GeminiCustomTTS()._tagged_text("Hola.", {}) == "Hola.")
check("tags applied when enabled",
      provider.GeminiCustomTTS()._tagged_text("Hola.", {"tags": True}) == "Hola <laugh>.")
check("already-tagged text is left alone",
      provider.GeminiCustomTTS()._tagged_text("Hola <sigh> qué tal.", {"tags": True}) == "Hola <sigh> qué tal.")
long_text = "palabra " * 6000
check("long text is not tagged (window guard)",
      provider.GeminiCustomTTS()._tagged_text(long_text, {"tags": True}) == long_text)


def _boom(system: str, user: str, fallback: str) -> str:
    raise RuntimeError("auxiliary down")


provider._rewrite_tags = _boom
check("a failing rewrite returns the original text",
      provider.GeminiCustomTTS()._tagged_text("Hola.", {"tags": True}) == "Hola.")
provider._rewrite_tags = _orig_rewrite

# the prompt is overridable; the shipped default covers the full tag vocabulary
_seen_prompt: list[str] = []
provider._rewrite_tags = lambda system, user, fallback: _seen_prompt.append(system) or fallback
provider.GeminiCustomTTS()._tagged_text("Hola.", {"tags": True, "tts_audio_tags_prompt": "MY PROMPT"})
check("tts_audio_tags_prompt overrides the default", _seen_prompt == ["MY PROMPT"], str(_seen_prompt))
_seen_prompt.clear()
provider.GeminiCustomTTS()._tagged_text("Hola.", {"tags": True})
check("empty override falls back to the built-in prompt",
      bool(_seen_prompt) and _seen_prompt[0] == provider._TAG_SYSTEM_PROMPT)
provider._rewrite_tags = _orig_rewrite
check("tag vocabulary includes the spaced and hyphenated ones",
      "heavy breath" in provider.TTS_AUDIO_TAGS and "throat-clearing" in provider.TTS_AUDIO_TAGS
      and "short pause" in provider.TTS_AUDIO_TAGS and len(provider.TTS_AUDIO_TAGS) == 40)
check("tagged-with-specials text is detected",
      bool(provider._TAGGED_RE.search("Hola <throat-clearing> y <heavy breath> ya.")))

# ---- chunk-cap contract: must fail loudly when Hermes changes -----------
try:
    from tools.tts_tool_delivery import PROVIDER_MAX_TEXT_LENGTH

    api._table.clear()
    PROVIDER_MAX_TEXT_LENGTH.pop("gemini-custom", None)
    check("contract ok after install", api.install_chunk_cap(strict=True) == 16000
          and api.chunk_cap_status() == (True, "ok"), str(api.chunk_cap_status()))

    _orig_table = api._provider_table
    api._provider_table = lambda: (_ for _ in ()).throw(
        api.ChunkCapContractError("gemini-custom: table gone (simulated)"))
    try:
        api.install_chunk_cap(strict=True)
        check("strict install raises on a broken contract", False, "no exception")
    except api.ChunkCapContractError:
        check("strict install raises on a broken contract", True)
    check("non-strict install degrades silently for the hook",
          api.install_chunk_cap(strict=False) is None)
    check("status reports the broken contract", api.chunk_cap_status()[0] is False,
          str(api.chunk_cap_status()))
    try:
        api.require_chunk_cap_contract()
        check("synthesize gate raises on a broken contract", False, "no exception")
    except api.ChunkCapContractError:
        check("synthesize gate raises on a broken contract", True)
    api._provider_table = _orig_table

    _orig_resolve = api._resolve_via_hermes
    api._resolve_via_hermes = lambda name, cap: 4000
    try:
        api.install_chunk_cap(strict=True)
        check("strict install raises when Hermes resolves another value", False, "no exception")
    except api.ChunkCapContractError as exc:
        check("strict install raises when Hermes resolves another value", "resolves 4000" in str(exc))
    api._resolve_via_hermes = _orig_resolve
    api._table.clear()
    api.install_chunk_cap(strict=True)
except ImportError:
    print("SKIP contract checks (tools.tts_tool_delivery not importable)")

print()
if FAILED:
    print(f"{len(FAILED)} FAILED: {', '.join(FAILED)}")
    raise SystemExit(1)
print("all checks passed")
