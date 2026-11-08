#!/usr/bin/env python3
"""Render speech with the gemini-custom provider from a shell (handy in the TUI).

    python3 ~/.hermes/plugins/gemini-custom/tools/render.py "Hola, ¿qué tal?" [--voice es-es-podcaster-5]
            [--model gemini-3.8-flash-tts] [--style "warm"] [--format ogg] [--out FILE]

Prints the written path plus a play command. Costs one API request.
"""

from __future__ import annotations

import argparse
import pathlib
import sys
import time

HERMES = pathlib.Path.home() / ".hermes" / "hermes-agent"
try:  # the install's venv already provides these
    from hermes_cli.plugins import _ensure_plugins_discovered  # noqa: E402
    from agent.tts_registry import get_provider  # noqa: E402
except ImportError:  # only then fall back to the checkout path
    sys.path.insert(0, str(HERMES))
    from hermes_cli.plugins import _ensure_plugins_discovered  # noqa: E402
    from agent.tts_registry import get_provider  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="Render a line with the gemini-custom TTS provider")
    ap.add_argument("text", nargs="+", help="text to speak")
    ap.add_argument("--voice")
    ap.add_argument("--model")
    ap.add_argument("--style", help='turn-level delivery, e.g. "warm and enthusiastic"')
    ap.add_argument("--format", default="ogg", choices=["ogg", "mp3", "wav", "flac"])
    ap.add_argument("--speed", type=float)
    ap.add_argument("--out", help="output path (default: cache/tts-demo/<timestamp>.<format>)")
    args = ap.parse_args()

    _ensure_plugins_discovered()
    provider = get_provider("gemini-custom")
    if provider is None:
        print("gemini-custom provider not registered — is the plugin enabled?", file=sys.stderr)
        return 2

    text = " ".join(args.text).strip()
    out = pathlib.Path(args.out) if args.out else (
        pathlib.Path.home() / ".hermes/cache/tts-demo" / f"tts_{time.strftime('%Y%m%d_%H%M%S')}.{args.format}")
    out.parent.mkdir(parents=True, exist_ok=True)

    written = provider.synthesize(text, str(out), voice=args.voice, model=args.model,
                                  speed=args.speed, style=args.style, format=args.format)
    size = pathlib.Path(written).stat().st_size
    print(f"wrote {written} ({size} bytes)")
    print(f"play:  ffplay -nodisp -autoexit -loglevel error {written}")
    print(f"       mpv --no-video {written}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
