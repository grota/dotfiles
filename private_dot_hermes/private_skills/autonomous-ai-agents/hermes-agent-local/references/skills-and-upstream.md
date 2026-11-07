# Bundled skills vs upstream (sync, diff, recovery)

How `hermes update` treats installed skills, and what to do if a bundled skill
ever gets edited locally (it must not — see the rule in SOUL.md).

## How sync decides

- `~/.hermes/skills/.bundled_manifest` holds `name:<hash>` for each bundled skill
  **as it was copied**. Stock sources live in `~/.hermes/hermes-agent/skills/`.
- Per skill: upstream hash unchanged → skip; upstream changed **and** the local
  copy still matches the recorded origin hash (pristine) → replace and re-record;
  upstream changed **and** the copy differs → `user-modified`, skipped, reported.
- The hash covers the whole skill directory, so one changed byte in one reference
  file marks the entire skill.

| Want | Command |
|---|---|
| list user-modified bundled skills | `hermes skills list-modified [--json]` (JSON is a bare array of names) |
| see the actual changes | `hermes skills diff <name>` — per-file unified diff, plus files only in yours |
| take the stock version back | `hermes skills reset <name> --restore --yes` |
| stop tracking a skill | `hermes skills reset <name>` — see the trap |
| stop syncing bundled skills at all | `hermes skills opt-out` / `opt-in` |

## Traps

- **`reset` without `--restore` is not "resume updates".** It deletes the manifest
  entry and keeps the copy; only a byte-identical copy is ever re-baselined, so the
  entry never returns. Upstream updates then skip the skill forever while
  `list-modified` reports "everything tracks upstream". It means "adopt my copy as
  a user skill".
- **`reset --restore` prompts and returns 0 when you answer no.** Non-interactively
  it prints "Cancelled" and exits successfully — a script that only checks the exit
  code believes it restored when nothing happened. Pass `--yes`, redirect stdin
  from `/dev/null`, and verify afterwards with `diff -rq`.
- **A `hermes` call inside `while read … done < file` eats that file on stdin.**
  Read the list on fd 3 (`done 3< file`) or redirect each child's stdin.
- **There is no update hook.** `VALID_HOOKS` covers agent/session/tool lifecycle —
  nothing fires on `hermes update`, and `pre_command` is slash commands only. A
  wrapper script is the only place to add a pre/post step.

## If a local edit already exists (recovery loop)

Only for salvaging an edit made before the read-only rule existed:

```bash
cd ~/.hermes
# 1. snapshot: full tree + a patch from a shared stripping root so -p1 lands right
cp -a skills/<cat>/<name> /tmp/<name>.tree
diff -ruN hermes-agent/skills/<cat>/<name> skills/<cat>/<name> > /tmp/<name>.patch
# 2. reset to stock, then VERIFY (diff -rq) — abort if it still differs
hermes skills reset <name> --restore --yes < /dev/null
diff -rq hermes-agent/skills/<cat>/<name> skills/<cat>/<name>
# 3. update, then re-apply the snapshot on top
hermes update
patch -p1 --batch --forward --merge < /tmp/<name>.patch
hermes skills list-modified          # expected: the skill is listed again
```

Prefer the *salvage into a local skill* route first: move the added content into
an agent-created skill, then reset the bundled one — that ends the diff instead of
keeping it alive. Salvage **before** forbidding: once the rule is in force the
hook below blocks the write that would add the content back.

## Shell hooks — making a rule enforced instead of requested

Hermes runs shell scripts on lifecycle events (`pre_tool_call`, `post_tool_call`,
`on_session_start`, …). Only `pre_tool_call` is **blocking**: exit 2 vetoes the
call, and stdout JSON `{"action":"block","message":"…"}` is what the model
reads. Everything else is an observer.

Register from the CLI — `hermes config set` YAML-parses list/mapping literals, so
the config file never gets a hand edit:

```bash
hermes config set hooks.pre_tool_call \
 '[{"command": "~/.hermes/agent-hooks/guard.sh", "matcher": "^(write_file|patch|skill_manage)$",
    "timeout": 10, "fail_closed": true}]'
```

`matcher` is a regex on the tool name, honoured only for `pre_tool_call` /
`post_tool_call`. `fail_closed` is honoured only on `pre_tool_call`; elsewhere it
is dropped with a warning (a broken observer must not stop the turn).

**Consent is a separate step from registration.** `hermes hooks list` shows
`(✗ not allowlisted)` until the script is approved, and `hermes hooks test` runs
it anyway — a green test does not mean the hook will fire. Approve with
`hooks_auto_accept: true` (global, blunt) or a one-shot
`hermes --accept-hooks chat -q "ok"`, which writes
`~/.hermes/shell-hooks-allowlist.json`. That file pins the script's **mtime**, so
editing the hook silently invalidates consent; `hermes hooks doctor` reports the
drift plus exec-bit and JSON-validity problems.

**Hooks register at process start.** A rule installed now does not guard the
session or gateway that installed it — say so, and give the restart
(`systemctl --user restart hermes-gateway` covers gateway turns; new CLI/TUI
sessions pick it up on their own).

**Hook payload has two shapes.** The real stdin payload carries `tool_name` and
`tool_input`; `hermes hooks test --payload-file f.json` instead merges the file
into the hook *kwargs* and re-serialises them, so tool arguments must sit under
`"args"`. A file shaped like the real payload yields `tool_input: null`, the hook
finds nothing, and a control test looks like a no-op. Test the script with a
wire-shaped payload, then once through `--for-tool <name>`.

**In this profile** the guardrail is `~/.hermes/agent-hooks/block-bundled-skill-writes.sh`
(`pre_tool_call`, matcher `^(write_file|patch|skill_manage)$`, `fail_closed: true`):
it resolves `path` / `file_path` (relative paths against the payload's `cwd`) and
`skill_manage` `operations[].name` against `.bundled_manifest`, and blocks any
write that lands in a bundled skill directory.
