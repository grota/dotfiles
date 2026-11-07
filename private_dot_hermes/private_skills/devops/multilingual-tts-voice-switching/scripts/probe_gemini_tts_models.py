#!/usr/bin/env python3
"""Probe every Gemini TTS model the API key can see, with the exact payload Hermes sends.

Usage:
    python3 probe_gemini_tts_models.py            # list + probe
    python3 probe_gemini_tts_models.py --list     # list only, no audio generated

Reads GOOGLE_API_KEY / GEMINI_API_KEY from the environment, then from the Hermes dotenv file
($HERMES_HOME/.env, default ~/.hermes/.env) — Hermes strips keys from the environment it hands
to tool subprocesses, so `env | grep KEY` proves nothing.

For each model it prints status, latency, byte count and the returned mimeType, and flags the
ones whose audio Hermes will wrap a second time (anything not raw L16/PCM -> audible tick).
Writes the audio under the scratch dir named by $TMPDIR or ~/.hermes/cache/scratch/gemini_tts.
"""

from __future__ import annotations

import base64
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

SENTENCE = "Hola, esta es una prueba corta para comprobar que el modelo devuelve audio."
BASE = "https://generativelanguage.googleapis.com/v1beta"


def hermes_home() -> pathlib.Path:
    return pathlib.Path(os.environ.get("HERMES_HOME") or pathlib.Path.home() / ".hermes")


def api_key() -> str:
    for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        value = os.environ.get(name)
        if value:
            return value.strip()
    dotenv = hermes_home() / ".env"
    if dotenv.exists():
        for line in dotenv.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            for name in ("GEMINI_API_KEY=", "GOOGLE_API_KEY="):
                if line.startswith(name):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("no Gemini API key in env or in the Hermes dotenv file")


def call(url: str, payload: dict | None, key: str) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data,
                                 headers={"Content-Type": "application/json", "x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.load(resp)


def tts_models(key: str) -> list[str]:
    listing = call(f"{BASE}/models?pageSize=1000", None, key)
    names = []
    for model in listing.get("models", []):
        name = model["name"].split("/", 1)[-1]
        methods = model.get("supportedGenerationMethods") or []
        if "tts" in name.lower() and "generateContent" in methods:
            names.append(name)
    return sorted(names)


def probe(model: str, key: str, outdir: pathlib.Path) -> None:
    payload = {
        "contents": [{"parts": [{"text": SENTENCE}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": "Kore"}}},
        },
    }
    started = time.time()
    try:
        data = call(f"{BASE}/models/{model}:generateContent", payload, key)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:300].replace("\n", " ")
        print(f"{model:34} HTTP {exc.code}  {body}")
        return
    except Exception as exc:  # noqa: BLE001 - probe reports, never raises
        print(f"{model:34} FAIL {type(exc).__name__}: {exc}")
        return
    elapsed = time.time() - started
    parts = data["candidates"][0]["content"]["parts"]
    inline = next((p["inlineData"] for p in parts if "inlineData" in p), None)
    if inline is None:
        print(f"{model:34} no audio; text parts: {[p.get('text', '')[:60] for p in parts]}")
        return
    audio = base64.b64decode(inline["data"])
    mime = inline.get("mimeType", "")
    outdir.mkdir(parents=True, exist_ok=True)
    suffix = ".wav" if audio[:4] == b"RIFF" else ".pcm"
    (outdir / f"{model}{suffix}").write_bytes(audio)
    warn = ""
    if suffix == ".wav":
        warn = "  <-- WAV: Hermes wraps it again, expect a 0.9 ms tick"
    print(f"{model:34} OK  {elapsed:5.1f}s  {len(audio) / 1024:6.0f} KiB  {mime}{warn}")


def main() -> int:
    key = api_key()
    models = tts_models(key)
    print(f"TTS models visible to this key: {len(models)}")
    for name in models:
        print(f"  {name}")
    if "--list" in sys.argv:
        return 0
    outdir = pathlib.Path(os.environ.get("TMPDIR") or
                          pathlib.Path.home() / ".hermes/cache/scratch/gemini_tts")
    print()
    for name in models:
        probe(name, key, outdir)
    print(f"\naudio written under {outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
