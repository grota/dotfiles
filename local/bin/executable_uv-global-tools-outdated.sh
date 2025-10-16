#!/usr/bin/env bash
set -euo pipefail
uv tool list --show-paths | awk '/^[^-]/{name=$1; if (match($0, /\(([^()]*)\)[[:space:]]*$/, m)) printf "%s\t%s\n", name, m[1]; }' | while IFS=$'\t' read -r name dir; do
  cd "$dir"
  uv pip list --outdated | grep -F "$name" || true
done
