"""Hermes plugin: ``gemini-custom`` TTS provider.

Registers a :class:`agent.tts_provider.TTSProvider` that speaks through the
Gemini 3.x ``interactions`` speech API. Selecting it is a config change:

    tts:
      provider: gemini-custom
      providers:
        gemini-custom:
          model: gemini-3.8-flash-tts
          voice: Kore
          style: "warm and enthusiastic"
"""

from __future__ import annotations

from .provider import GeminiCustomTTS

_PROVIDER = GeminiCustomTTS()


def register(ctx) -> None:
    """Plugin entry point: hand the provider to Hermes' TTS registry."""
    ctx.register_tts_provider(_PROVIDER)
