#!/usr/bin/env bash
# pre_tool_call guardrail: refuse writes into upstream-owned (bundled) skills.
#
# Wired from ~/.hermes/config.yaml:
#   hooks:
#     pre_tool_call:
#       - matcher: "^(write_file|patch|skill_manage)$"
#         command: "~/.hermes/agent-hooks/block-bundled-skill-writes.sh"
#         timeout: 10
#         fail_closed: true
#
# Exit 2 blocks the call; the JSON on stdout is the message the model sees.
# Reads the payload from stdin into a temp file first, because the logic below
# needs its own stdin-free invocation (heredocs would eat the payload).

set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp "${TMPDIR:-/tmp}/hermes-hook.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp"
exec python3 "$here/block_bundled_skill_writes.py" "$tmp"
