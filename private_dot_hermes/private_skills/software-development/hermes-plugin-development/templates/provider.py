"""Provider skeleton. Copy, rename, fill in the methods that matter.

Rules that are easy to get wrong:
  * is_available() must not network and must not raise — it runs on every dispatch.
  * voice_compatible opt-in: default False ships a file, not a voice bubble.
  * synthesize() must raise on failure and write exactly output_path.
  * stream() may run concurrently; keep it stateless.
"""

from __future__ import annotations

from typing import Any, Iterator, Optional

from agent.tts_provider import TTSProvider


class MyProvider(TTSProvider):
    streams_pcm = False          # True only if stream() yields raw int16 PCM

    @property
    def name(self) -> str:
        return "my-provider"     # must not equal a built-in provider name

    @property
    def voice_compatible(self) -> bool:
        return True

    def is_available(self) -> bool:
        return bool(self._key())  # no network here

    def _key(self) -> Optional[str]:
        import os
        for var in ("MY_API_KEY",):
            if (os.environ.get(var) or "").strip():
                return os.environ[var].strip()
        return None              # then fall back to the profile dotenv, per call

    def list_voices(self) -> list[dict[str, Any]]:
        return []                # [{"id": ..., "display": ..., "language": ...}]

    def synthesize(self, text: str, output_path: str, *, voice: Optional[str] = None,
                   model: Optional[str] = None, speed: Optional[float] = None,
                   format: str = "mp3", **extra: Any) -> str:
        raise NotImplementedError

    def stream(self, text: str, *, voice: Optional[str] = None,
               model: Optional[str] = None, format: str = "opus",
               **extra: Any) -> Iterator[bytes]:
        raise NotImplementedError
