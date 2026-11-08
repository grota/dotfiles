# Shell hooks (`pre_tool_call` guardrails)

Hermes shell hooks are how you make a rule enforceable instead of advisory
("never write into bundled skills"), or veto/rewrite a call the model should
not make. `pre_tool_call` is the only blocking event.

## Register one

1. Write the script under `~/.hermes/agent-hooks/`. A `.sh` with a shebang runs
directly on POSIX; put the logic in a sibling `.py`. The payload arrives on
**stdin**, so a heredoc inside the wrapper would eat it — copy it to a temp file
(`cat > "$tmp"`) and pass the path to the interpreter.
2. Register with a YAML/JSON literal — `hermes config set` auto-parses structured
values, so no hand-editing of `config.yaml`:
   ```bash
   hermes config set hooks.pre_tool_call '[
     {"command": "~/.hermes/agent-hooks/block-x.sh",
      "matcher": "^(write_file|patch|skill_manage)$",
      "timeout": 10, "fail_closed": true}]'
   ```
   `hooks.<event>` needs no `--force`; `hermes config get hooks.pre_tool_call`
   echoes the parsed structure back.
3. **Consent is separate from registration.** Until allowlisted the hook is inert
   and `hermes hooks list` prints `✗ not allowlisted`. Seed consent from a CLI run
   so no approval card ever appears in a chat channel:
   ```bash
   hermes --accept-hooks chat -q "Reply with exactly: OK"
   ```
   Then `~/.hermes/shell-hooks-allowlist.json` holds the entry and the list shows
   `✓ allowed`. `hermes --accept-hooks hooks list` does **not** work — the
   subcommand never registers hooks.
4. `hermes hooks doctor` — exec bit, allowlist, mtime drift, and a clean run.

## Blocking contract

- Exit code **2** blocks a `pre_tool_call` even with no output; stdout JSON
  `{"action": "block", "message": "…"}` is the text the model sees. Emit both.
- Payload keys: `tool_name`, `tool_input` (the tool's argument dict), `cwd`,
  `session_id`, `profile`.
- `fail_closed: true` makes a crashing or timing-out hook block rather than
  allow, which is what a guardrail wants; observer hooks should leave it false.
- Check both addressing styles: path tools (`write_file`, `patch` → `path`, resolve
  against `payload["cwd"]`) and name-addressed tools (`skill_manage` →
  `operations[].name`, no path at all).

## Pitfalls

- **`hermes hooks test <event> --payload-file f.json` does not send your JSON as
  the wire payload.** It merges the file into synthetic *kwargs* and serializes
  those, so a top-level `tool_input` lands in `extra` and the hook receives
  `tool_input: null`. Put the arguments under `"args"` and pass
  `--for-tool <tool name>` so the matcher is applied too.
- **Hooks register at process start.** A running gateway or TUI keeps the old set
  until it restarts (`systemctl --user restart hermes-gateway`, or a new session),
  so "I added the hook" is not "the hook is active".
- **Consent pins the script's mtime.** Editing the script — or a dotfile manager
  re-applying it — invalidates approval; `doctor` reports the drift and
  `hermes --accept-hooks` re-approves.
- **`VALID_HOOKS` has no update/install event.** Lifecycle hooks cover tool calls,
  LLM calls, sessions, kanban, approvals, gateway events; nothing fires on
  `hermes update`, and `pre_command` is slash commands only. A pre/post step for
  an update has to live in a wrapper script the user calls.
