#!/usr/bin/env python3
"""Block tool calls that would write into an upstream-owned (bundled) skill.

A skill is upstream-owned when its name appears in
``$HERMES_HOME/skills/.bundled_manifest``. Those skills are read-only: any local
edit freezes them out of ``hermes update`` (the sync compares a hash of the whole
skill directory and skips a differing copy forever).

Exit 2 blocks the call and prints the block message as JSON (the shape
``pre_tool_call`` understands). Exit 0 allows it.
"""

from __future__ import annotations

import json
import os
import sys


def main() -> int:
    try:
        with open(sys.argv[1], encoding="utf-8") as fh:
            payload = json.load(fh)
    except (OSError, ValueError, IndexError):
        return 0  # unreadable payload: fail open, never block on our own bug

    if not isinstance(payload, dict):
        return 0

    args = payload.get("tool_input") or {}
    if not isinstance(args, dict):
        return 0
    cwd = payload.get("cwd") or os.getcwd()

    home = os.environ.get("HERMES_HOME") or os.path.join(os.path.expanduser("~"), ".hermes")
    skills = os.path.realpath(os.path.join(home, "skills"))
    manifest = os.path.join(skills, ".bundled_manifest")

    try:
        with open(manifest, encoding="utf-8-sig") as fh:
            bundled = {line.split(":", 1)[0].strip() for line in fh if line.strip()}
    except OSError:
        return 0  # no manifest, nothing is upstream-owned
    if not bundled:
        return 0

    def block(name: str, target: str) -> int:
        print(json.dumps({
            "action": "block",
            "message": (
                f"'{name}' is an upstream-owned bundled skill ({target}). Bundled skills are "
                "read-only: editing one freezes it out of `hermes update` forever. Put the "
                "knowledge in an agent-created skill (`hermes-agent-local` for Hermes itself) "
                "or report the fix to the user instead."
            ),
        }))
        return 2

    # skill_manage addresses the skill by name, not by path.
    for op in args.get("operations") or []:
        if isinstance(op, dict) and op.get("name") in bundled:
            return block(str(op["name"]), "skill_manage operation")
    if args.get("name") in bundled:
        return block(str(args["name"]), "skill_manage")

    # write_file / patch address it by path.
    for raw in (args.get("path"), args.get("file_path")):
        if not isinstance(raw, str) or not raw.strip():
            continue
        full = os.path.realpath(os.path.join(cwd, os.path.expanduser(raw)))
        if not (full == skills or full.startswith(skills + os.sep)):
            continue
        rel = os.path.relpath(full, skills)
        parts = rel.split(os.sep)
        victim = parts[1] if len(parts) > 1 else parts[0]
        if victim in bundled:
            return block(victim, rel)

    return 0


if __name__ == "__main__":
    sys.exit(main())
