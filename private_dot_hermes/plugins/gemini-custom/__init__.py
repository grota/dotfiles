"""Hermes plugin: ``gemini-custom`` TTS provider.

Registers a :class:`agent.tts_provider.TTSProvider` that speaks through the
Gemini 3.x ``interactions`` speech API, and publishes the provider's chunk cap
into Hermes' own table so nothing has to be written to ``config.yaml``:

    tts:
      provider: gemini-custom
      providers:
        gemini-custom:
          model: gemini-3.8-flash-tts
          voice: Leda
          style: "warm and natural"

The cap is Hermes-side: ``text_to_speech`` splits a long reply *before* any
provider code runs, reading ``tools.tts_tool_delivery.PROVIDER_MAX_TEXT_LENGTH``.
Publishing an entry at registration time (and refreshing it from the
``pre_llm_call`` hook, one metadata request per model per 30 days) removes the
need for a duplicate ``tts.gemini-custom.max_text_length`` key — the reason this
plugin used to need two places in config and raised a schema warning.
"""

from __future__ import annotations

from . import gemini_api as api
from .provider import GeminiCustomTTS

_PROVIDER = GeminiCustomTTS()


def register(ctx) -> None:
    """Plugin entry point: TTS provider + chunk cap (table entry, no config key)."""
    ctx.register_tts_provider(_PROVIDER)
    api.install_chunk_cap(allow_network=False, strict=True)  # cached value or the documented fallback
    try:
        ctx.register_hook("pre_llm_call", api.refresh_chunk_cap)
    except Exception:  # a host without hooks must still speak
        pass
