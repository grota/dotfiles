"""Probe a provider's model list with real completions and classify each result.

Usage:
    set -a && . ~/.hermes/.env && set +a
    python3 scripts/probe_models.py --base-url https://provider/v1 --key-env OPENAI_API_KEY
    python3 scripts/probe_models.py --base-url ... --key-env ... --models a,b,c

Stdlib only. Never prints the API key. Reads the key from the named env var so
the credential never appears in argv, shell history, or a process listing.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

# Many provider edges 403 a bare urllib agent while accepting a curl-like one.
UA = "curl/8.5.0"
DEFAULT_TIMEOUT = 45


def classify(status: str, error: str) -> str:
    """Map a failure onto the taxonomy so the report is actionable, not raw."""
    text = (error or "").lower()
    if "country" in text or "region" in text or "not available in your" in text:
        return "geo-block"
    if "only be used from within" in text or "only within" in text:
        return "client-gate"
    if status == "unauthorized" or "api key" in text or "authentication" in text:
        return "auth"
    if status == "not_found" or "model_not_found" in text or "does not exist" in text:
        return "naming"
    if "rate limit" in text or "too many requests" in text:
        return "throttled"
    return "other"


def request(url: str, key: str, *, body: dict | None, timeout: int) -> tuple[int, dict | str]:
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": f"Bearer {key}", "User-Agent": UA}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            return exc.code, json.loads(raw)
        except ValueError:
            return exc.code, raw
    except Exception as exc:  # transport failure is a verdict of "other", not a crash
        return 0, f"{type(exc).__name__}: {exc}"


def error_text(payload: dict | str) -> str:
    if isinstance(payload, str):
        return payload.strip()[:160]
    err = payload.get("error")
    if isinstance(err, dict):
        return str(err.get("message") or err)[:160]
    if isinstance(err, str):
        return err[:160]
    return str(payload.get("message") or payload)[:160]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True, help="e.g. https://provider/v1")
    parser.add_argument("--key-env", required=True, help="env var holding the API key")
    parser.add_argument("--models", help="comma-separated IDs; default = every advertised ID")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    parser.add_argument("--retries", type=int, default=2, help="retries for transient classes")
    args = parser.parse_args()

    key = os.environ.get(args.key_env, "")
    if not key:
        print(f"{args.key_env} is not set", file=sys.stderr)
        return 2

    base = args.base_url.rstrip("/")
    code, listing = request(f"{base}/models", key, body=None, timeout=args.timeout)
    if code != 200 or not isinstance(listing, dict) or "data" not in listing:
        print(f"listing failed ({code}): {error_text(listing)}", file=sys.stderr)
        print("If this is a 403, add a User-Agent header — the edge filters default agents.",
              file=sys.stderr)
        return 1

    advertised = [m.get("id") for m in listing["data"] if isinstance(m, dict)]
    targets = (
        [m.strip() for m in args.models.split(",") if m.strip()]
        if args.models
        else advertised
    )
    missing = [m for m in targets if m not in advertised]
    if missing:
        print(f"note: not in the advertised list, probing anyway: {missing}", file=sys.stderr)

    print(f"# {len(targets)} candidate(s) from {base}\n")
    rows, working = [], []
    for model in targets:
        body = {
            "model": model,
            "messages": [{"role": "user", "content": "Reply with exactly: PONG"}],
            "max_tokens": 20,
        }
        attempt, code, payload = 0, 0, ""
        while True:
            started = time.monotonic()
            code, payload = request(f"{base}/chat/completions", key, body=body, timeout=args.timeout)
            elapsed = round(time.monotonic() - started, 2)
            attempt += 1
            if code == 200 and isinstance(payload, dict) and payload.get("choices"):
                break
            kind = classify("ok" if code == 200 else "error", error_text(payload))
            if kind in {"throttled", "other"} and attempt <= args.retries:
                time.sleep(1.5 * attempt)
                continue
            break

        if code == 200 and isinstance(payload, dict) and payload.get("choices"):
            try:
                reply = (payload["choices"][0]["message"]["content"] or "").strip()[:40]
            except (KeyError, IndexError, TypeError):
                reply = ""
            rows.append((model, "ok", elapsed, reply))
            working.append(model)
            print(f"[ok]    {model:<40} {elapsed:>6}s  {reply}")
        else:
            detail = error_text(payload)
            kind = classify("error", detail)
            rows.append((model, kind, elapsed, detail))
            print(f"[FAIL]  {model:<40} {elapsed:>6}s  [{kind}] {detail}")

    print("\n# summary")
    print(json.dumps({
        "working": working,
        "failed": {m: k for m, k, _, _ in rows if k != "ok"},
    }, indent=2))
    print("\nOnly commit a config change to an id listed under 'working'.", file=sys.stderr)
    return 0 if working else 1


if __name__ == "__main__":
    raise SystemExit(main())
