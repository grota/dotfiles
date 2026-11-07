"""Plugin entry point: register one provider instance with Hermes.

The provider object must be cheap to construct — it is created at discovery time,
before any key or config is guaranteed to exist. Resolve credentials and config
inside the provider's methods, per call (see provider.py).
"""

from __future__ import annotations

from .provider import MyProvider

_PROVIDER = MyProvider()


def register(ctx) -> None:
    ctx.register_tts_provider(_PROVIDER)   # or register_transcription_provider / …
