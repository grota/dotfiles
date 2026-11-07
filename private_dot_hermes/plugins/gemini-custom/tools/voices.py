#!/usr/bin/env python3
"""Search the Gemini voice catalogue (cached copy of GET /v1beta/voices).

    python3 ~/.hermes/plugins/gemini-custom/tools/voices.py --language es-ES
    python3 ~/.hermes/plugins/gemini-custom/tools/voices.py --grep podcaster --language es
    python3 ~/.hermes/plugins/gemini-custom/tools/voices.py --stats

No API request when the cache is fresh (24 h); `--refresh` re-fetches.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

HERMES = pathlib.Path.home() / ".hermes" / "hermes-agent"
if str(HERMES) not in sys.path:
    sys.path.insert(0, str(HERMES))

CACHE = pathlib.Path.home() / ".hermes/cache/gemini_voices.json"


def load(refresh: bool) -> list[dict]:
    if refresh or not CACHE.exists():
        sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
        from gemini_api import list_voice_catalog, resolve_api_key

        key = resolve_api_key()
        if not key:
            print("no GEMINI_API_KEY / GOOGLE_API_KEY available", file=sys.stderr)
            return []
        return list_voice_catalog(api_key=key, cache_path=CACHE)
    return json.loads(CACHE.read_text(encoding="utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser(description="Browse the Gemini voice catalogue")
    ap.add_argument("--language", help="locale prefix, e.g. es, es-ES, es-419")
    ap.add_argument("--grep", help="substring match on id / display name / persona")
    ap.add_argument("--gender")
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument("--stats", action="store_true", help="counts by locale")
    ap.add_argument("--refresh", action="store_true", help="re-fetch from the API")
    args = ap.parse_args()

    voices = load(args.refresh)
    if not voices:
        return 1

    if args.stats:
        from collections import Counter

        counts = Counter(v.get("language_code", "?") for v in voices)
        print(f"{len(voices)} voices, {len(counts)} locales")
        for locale, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:25]:
            print(f"  {locale:10} {n:4}")
        return 0

    lang = (args.language or "").lower()
    rows = [v for v in voices
            if (not lang or str(v.get("language_code", "")).lower().startswith(lang))
            and (not args.gender or str(v.get("gender", "")).lower() == args.gender.lower())
            and (not args.grep or args.grep.lower() in json.dumps(v, ensure_ascii=False).lower())]
    print(f"{len(rows)} match(es); showing {min(len(rows), args.limit)}")
    for v in rows[: args.limit]:
        print(f"  {str(v.get('id')):26} {str(v.get('language_code')):8} {str(v.get('gender')):8} "
              f"{str(v.get('accent'))[:20]:20} {str(v.get('persona'))[:34]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
