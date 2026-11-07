#!/usr/bin/env python3
"""Prove a Hermes provider plugin actually landed in its registry.

    cd ~/.hermes/hermes-agent && <hermes-venv-python> \
        <skills-dir>/hermes-plugin-development/scripts/verify_registration.py \
        <provider-name> [--registry tts|stt|delegation|browser]

Exit 1 when the provider is not registered — `hermes plugins doctor` does not
cover provider registrations, so this is the check that matters.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

HERMES = pathlib.Path.home() / ".hermes" / "hermes-agent"
if str(HERMES) not in sys.path:
    sys.path.insert(0, str(HERMES))

REGISTRIES = {
    "tts": ("agent.tts_registry", "get_provider"),
    "stt": ("agent.transcription_registry", "get_provider"),
    "delegation": ("agent.delegation_registry", "get_provider"),
    "browser": ("agent.browser_registry", "get_provider"),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--registry", default="tts", choices=sorted(REGISTRIES))
    args = ap.parse_args()

    try:
        from hermes_cli.plugins import _ensure_plugins_discovered

        _ensure_plugins_discovered()
    except Exception as exc:  # discovery failure is itself the finding
        print(f"plugin discovery failed: {type(exc).__name__}: {exc}")
        return 1

    module_name, getter = REGISTRIES[args.registry]
    try:
        module = __import__(module_name, fromlist=[getter])
        get = getattr(module, getter)
    except Exception as exc:
        print(f"registry {module_name} unavailable: {type(exc).__name__}: {exc}")
        return 1

    provider = get(args.name)
    if provider is None:
        print(f"NOT REGISTERED: '{args.name}' is absent from the {args.registry} registry")
        print("  check: built-in name collision, plugin not enabled, or register(ctx) never ran")
        return 1

    print(f"registered: {provider} ({type(provider).__name__})")
    for attr in ("name", "display_name", "is_available", "streams_pcm", "stream_sample_rate",
                 "voice_compatible", "default_model", "default_voice"):
        if not hasattr(provider, attr):
            continue
        try:
            value = getattr(provider, attr)
            value = value() if callable(value) else value
        except Exception as exc:
            value = f"<raised {type(exc).__name__}: {exc}>"
        print(f"  {attr:20} {value!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
