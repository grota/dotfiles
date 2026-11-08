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
    "gemini-2.5-flash-preview-tts": "Gemini 2.5 Flash TTS (preview)",
    "gemini-2.5-pro-preview-tts": "Gemini 2.5 Pro TTS (preview, needs billing)",
}

MIME_BY_FORMAT = {
    "wav": "audio/wav",
    "l16": "audio/l16",
    "mulaw": "audio/mulaw",
    "alaw": "audio/alaw",
}


class GeminiTTSError(RuntimeError):
    """Any failure talking to the Gemini TTS API (message is user-facing)."""


def _hermes_home() -> Path:
    return Path(os.environ.get("HERMES_HOME") or (Path.home() / ".hermes"))


KEY_ENV_NAMES = ("GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GENERATIVE_AI_API_KEY")


def resolve_api_key() -> Optional[str]:
    """First key found: env, then the profile dotenv.

    ``GOOGLE_GENERATIVE_AI_API_KEY`` is the name Google's own SDKs use and what a
    ``secrets.command`` helper commonly exports (it is the one a shell process
    sees here); ``GEMINI_API_KEY`` may be an unresolved ``${...}`` reference
    outside the gateway, so it is tried first but never trusted blindly.
    """
    for name in KEY_ENV_NAMES:
        value = (os.environ.get(name) or "").strip()
        if value and "$" not in value:
            return value
    dotenv = _hermes_home() / ".env"
    try:
        for line in dotenv.read_text(encoding="utf-8", errors="replace").splitlines():
            name, sep, value = line.strip().partition("=")
            if sep and name in KEY_ENV_NAMES:
                value = value.strip().strip('"').strip("'")
                if value and "$" not in value:
                    return value
    except OSError:
        pass
    return None


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
            detail = exc.read().decode("utf-8", "replace")[:400]
            last_error = f"HTTP {exc.code}: {detail}"
            retryable = exc.code == 429 or 500 <= exc.code < 600
            if not retryable or attempt >= retries:
                raise GeminiTTSError(f"Gemini TTS {last_error}") from exc
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


def stream_request(payload: dict[str, Any], *, api_key: str, timeout: float,
                   retries: int) -> Iterator[bytes]:
    """Yield raw audio chunks from an SSE ``stream: true`` interaction."""
    text = _post(INTERACTIONS_URL, payload, timeout=timeout, retries=retries,
                 stream=True, api_key=api_key)
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
