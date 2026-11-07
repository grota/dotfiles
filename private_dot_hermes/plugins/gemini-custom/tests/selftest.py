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
single = api.build_payload(model="m", turns=[{"text": "hola", "style": "warm"}], voice="Kore",
                           mime_type="audio/l16", sample_rate=24000)
check("payload single speech_config is list", single["generation_config"]["speech_config"] == [{"voice": "Kore"}])
check("payload annotations", single["input"][0]["content"][0]["annotations"] ==
      [{"type": "speech_metadata", "style": "warm"}])
check("payload response_format", single["response_format"] ==
      {"type": "audio", "mime_type": "audio/l16", "sample_rate": 24000})
check("payload no stream flag", "stream" not in single)

multi = api.build_payload(model="m", turns=[{"text": "a", "speaker": "A"}, {"text": "b", "speaker": "B"}],
                          voice="Kore", speakers=[{"speaker": "A", "voice": "Kore"},
                                                  {"speaker": "B", "voice": "Puck"}])
check("payload multi speakers object", multi["generation_config"]["speech_config"]["speakers"][1] ==
      {"speaker": "B", "voice": "Puck"})
check("payload multi turns have speaker", [t.get("annotations", [{}])[0].get("speaker")
                                           for t in multi["input"][0]["content"]] == ["A", "B"])

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
_orig_sections, _orig_override = provider._load_config_sections, provider._load_override_file
provider._load_config_sections = lambda: [{"model": "from-config", "voice": "voice-config"}]
provider._load_override_file = lambda: {"voice": "voice-runtime"}
settings = provider.resolve_settings(model="dispatcher-model", voice="dispatcher-voice", speed=1.5)
check("precedence config<kwargs<runtime",
      settings["model"] == "dispatcher-model" and settings["voice"] == "voice-runtime"
      and settings["speed"] == 1.5, json.dumps({k: settings[k] for k in ("model", "voice", "speed")}))
provider._load_config_sections, provider._load_override_file = _orig_sections, _orig_override

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

print()
if FAILED:
    print(f"{len(FAILED)} FAILED: {', '.join(FAILED)}")
    raise SystemExit(1)
print("all checks passed")
