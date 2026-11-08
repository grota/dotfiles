# config.yaml edits, reload tiers, and credentials

Local additions to the bundled `references/configuration.md` and
`references/providers-and-models.md` in the `hermes-agent` hub.

## Editing pitfalls

- `hermes config set` can write sibling defaults it knows about, not just the key
  you named. Re-read the whole section afterwards
  (`sed -n '/^tts:/,/^[a-z]/p' config.yaml`): an option that was merely implied,
  and inert for this setup, becomes explicit and starts logging on every run.
- Schema-less paths such as `tts.providers.<name>.*` are refused without
  `--force`; `--force` is also how you write any key the schema does not know.
- **List and mapping values go in as YAML/JSON literals** —
  `hermes config set hooks.pre_tool_call '[{...}]'` — so structured settings
  (hooks, routes, allowlists) never require hand-editing `config.yaml`. Invalid
  YAML is refused rather than stored as a string; a key whose default is a string
  keeps the value verbatim unless it parses as a list/mapping, and quoting forces
  a plain string.
- API keys are stripped from the environment handed to **tool subprocesses**, so
  `env | grep KEY` inside a terminal call proves nothing about whether Hermes
  holds that key. Filter by name not line when you do look:
  `env | cut -d= -f1 | grep KEY` (a case-insensitive grep also matches values —
  PATH entries mention install dirs, not credentials).
- **`/proc/<pid>/environ` is an exec-time snapshot, not the live environment.**
  A `secrets.command` helper's output is merged into the process's `os.environ`
  after exec, so it never appears there: a gateway started by its systemd unit
  shows only the unit's own variables even with 30 secrets loaded. The
  authoritative evidence is the startup line in the journal/`hermes doctor`:
  `Command helper: applied N secrets`. Conversely a TUI/`hermes chat` process may
  show every key in `/proc` because it inherited an interactive shell — so
  comparing two Hermes processes' `/proc` environments, in either direction,
  proves nothing about credential availability.

## Reload, re-session or restart?

Config reads are cached on the file's signature, so a write to `config.yaml` is
visible to the very next read inside the running gateway. What differs is *who
reads it and when*:

| Tier | What lands there |
|---|---|
| **Next read** — no restart, no new session | `tts.*`, `stt.*`, `approvals.*`, `security.*`, `compression.*`, `display.*`, `agent.max_turns`, `delegation.*`, `curator.*`, cron schedules (next tick) |
| **Next session (`/new`)** | anything that shapes the prompt — toolsets, skills preload, prompts, AGENTS.md — and values frozen at session creation: model, provider, toolsets, yolo, checkpoints |
| **`hermes gateway restart`** | `platforms.<name>.*` (tokens, enabled set), the Telegram command menu, `webapp.*`, `gateway.*`, *adding* `mcp_servers` entries (removals/re-enables are watched within ~a minute or `/reload-mcp`), hand-edited `plugins.enabled`, and a *removed* `.env` variable — a miss falls back to the value loaded at gateway start |

`auxiliary.<task>` is read per call, but a gateway session freezes a copy at
session start, so aux-route edits land on the next session. Rule of thumb: a
value read by the code handling the turn is live; a value baked into a session or
a boot-time adapter is not.

## The voice is language-bound and global

No provider detects the language of the text: the one configured voice
(`tts.edge.voice`, `tts.elevenlabs.voice_id`, `tts.openai.voice`,
`tts.gemini.voice`, `tts.xai.voice_id` + `tts.xai.language`) reads every reply.
An English voice id on Spanish/Italian text is exactly what "speaks my language
with an English accent" means — change the voice id, not the provider.
Troubleshooting entry: *speaks with the wrong accent* → `hermes config get
tts.edge.voice`, then `hermes config set tts.edge.voice es-ES-XimenaNeural`.
Inventory and comparison clips: `references/tts-voices.md` +
`scripts/edge_voice_compare.py`.

## Credentials from the environment instead of copies in `.env`

`.env` is parsed raw and then interpolated at load time: `${VAR}` and
`${VAR:-default}` resolve against the process environment, with Hermes's own
earlier dotenv output peeled back, so a self-reference reads the shell value
rather than itself (`hermes_cli/env_loader.py::_resolve_dotenv_assignments`).

```bash
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}     # keeps the key's name visible
```

- The home `.env` loads with `override=True`, so a **literal** in it beats a shell
  export. To let the shell win, reference it as above or drop the line.
- Unset in the environment → the key resolves to nothing and stays unset;
  `${VAR:-fallback}` supplies a default.
- Values are captured at process start — a changed variable reaches only a new
  process.
- **The gateway is a service**, so "the environment" there belongs to the service
  manager (systemd user unit / launchd / s6), not an interactive shell. An
  `export` in `.bashrc` reaches `hermes chat` and the TUI only. For the gateway:
  `systemctl --user set-environment K=V` (volatile), `~/.config/environment.d/`
  (read at manager start, needs re-login), or a unit drop-in with
  `EnvironmentFile=` (mode 600, needs `daemon-reload` + restart). Then restart the
  unit; a running process never re-reads its environment.
- **systemd cannot read shell-syntax files**: `EnvironmentFile=` wants plain
  `KEY=value`, no `export`, no `$(...)`. A dotfile-rendered `export FOO=bar` file
  has to be re-rendered in that shape (one source, two renders), not copied.
- **A `hermes secrets` command helper cannot echo the current shell value for the
  gateway**: helpers run as Hermes's child, so on the service side they inherit the
  service manager's minimal environment, not the interactive shell. A helper has
  to read the secret store (or the deployed, already-decrypted file) itself.
- **Vault-backed keys avoid the whole problem**: `hermes secrets bitwarden` (bws
  machine account, headless), `hermes secrets onepassword` (op:// references), or
  a command helper for any CLI vault that prints `KEY=VALUE`. Sources fetch at
  process startup, so gateway, TUI, cron and subagents all get the same values
  with no systemd environment at all. `.env` then holds only the bootstrap token
  (`BWS_ACCESS_TOKEN` / `OP_SERVICE_ACCOUNT_TOKEN`). Precedence: `.env`/shell wins
  unless the source sets `override_existing: true` (Bitwarden defaults to true);
  `secrets.preserve_existing` pins names that must differ per profile, and
  `secrets.profile_alias` lets `FOO_<PROFILE>` hydrate `FOO` inside that profile.
- Env vars are readable by the same user via `/proc/<pid>/environ` and are
  inherited by child processes, which a 0600 `.env` avoids.
- Static keys are per-profile; OAuth logins are not — they live in the root
  `auth.json` and are shared (see `references/profiles-and-gateways.md`).

## Implementing a `secrets.command` helper (bulk source)

```yaml
secrets:
  command:
    enabled: true
    command: /abs/path/helper      # run via /bin/sh -c
    override_existing: false       # false = additive; .env/shell keeps winning
```

Contract (`agent/secret_sources/command.py`):

- runs **once per process at startup** with `HERMES_SECRET_KEY=""`; stdout is
  parsed as one KEY=VALUE map, stderr is captured and discarded
- 3 s hard timeout (`helper_timeout_seconds`), 1 MiB output cap; every failure
  degrades to "no value" so a broken helper never blocks startup
- the parser is an anchored `^([A-Za-z_][A-Za-z0-9_]*)=(.*)$`, therefore **an
  `export KEY=value` line is skipped silently** — a helper reading a bash env file
  must strip the prefix
- one layer of surrounding quotes is stripped per value; values are never
  shell-expanded, so filter the file, never `source` it
- POSIX-only (`/bin/sh`)

Minimal helper over a bash env file:

```sh
sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/\2=\3/p' "$file"
```

**One pass, one `-e` script.** A second `-e` expression runs on the already
substituted pattern space and emits every line twice — harmless to the parsed
map, but it inflates output and hides real duplicates.

Verify with `hermes doctor | grep -i 'command helper'` → `applied N secrets`. With
`override_existing: false`, N counts only keys that were **missing** from
`.env`/shell; diff key *names* to see what a migration will really do:

```bash
comm -23 <(helper | cut -d= -f1 | sort -u) \
         <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' ~/.hermes/.env | tr -d '=' | sort -u)
```

## Which env var does a provider want?

Never guess from the provider id. The registry tuple is authoritative:

```bash
grep -n '("opencode-zen"' ~/.hermes/hermes-agent/hermes_cli/auth.py
# ("<id>", "<label>", "<base_url>", ("<ENV_VAR>",), ...)
```

Some ids do not follow the obvious mapping (`lmstudio` reads `LM_API_KEY`), and
OAuth providers (`anthropic` via Claude Pro, `openai-codex`, `xai`) have no env
var at all — their credential is a token in `auth.json`. Two cheap cross-checks:
`hermes doctor | grep -i missing` names the variable for anything unresolved, and
`hermes auth add <provider> --type api-key` resolves an id to its credential slot.

## Provider keys do not flow from a source (verified)

With `override_existing: false` a source is strictly additive, and the model
provider is resolved through a path that did not see source-supplied values on a
real install: with the provider's `.env` line removed and the helper emitting the
exact name, `hermes doctor` reported the provider configured and a direct
`resolve_api_key_provider_credentials()` returned the value, yet `hermes chat -q`
still failed with `No usable credentials found for provider '<id>'`.

So treat model-provider credentials as `.env`-or-pool:

- keep the provider's key in `.env` — one line, and every entry point works; or
- store it in the credential pool with `hermes auth add <provider> --type api-key`
  (`_resolve_api_key_provider_secret()` consults the pool after env).

Source-supplied keys are for tool credentials — search, crawl, OCR, embeddings,
TTS — not for the provider that runs the turn.

## Migrating `.env` to a source

1. Diff key **names** first. A provider can want a differently named variable
   than the one in the env file (a wrapper key vs the upstream `_API_KEY`);
   deleting the only copy of a name the active provider needs breaks the agent,
   not the helper.
2. Leave channel and bot configuration in `.env` (`*_BOT_TOKEN`, allowlists,
   browser/terminal tuning): a secret source is for provider keys, not gateway
   config.
3. Start with `override_existing: false` (additive, cannot regress anything);
   flip to `true` only when the source is meant to be authoritative.
4. The decrypted target of an encrypted dotfile must be 0600 (`chezmoi chattr
   +private`) — a plain `add` leaves 0644, which defeats the encryption.
5. Restart the gateway **last**: sources resolve at process start, so a live
   gateway keeps running on the old values until then.

### Prove each key before deleting it

```bash
cp ~/.hermes/.env /tmp/env.bak
sed -i 's/^PROVIDER_KEY=/#PROVIDER_KEY=/' ~/.hermes/.env    # comment, do not delete
hermes chat -q "reply OK"      # or trigger the tool that needs the key
# failure => restore: cp /tmp/env.bak ~/.hermes/.env
```

Failures are silent until the consumer runs — the helper still prints
`applied N secrets`, so only the consumer tells you the name was wrong or the
value unreachable. One key per iteration, least-used first.

## Secret hygiene while working near key files

- Never let a value reach tool output. Pipe through `sed`/`awk`/`python` that
  prints names, counts, lengths or names-only diffs.
- When the user asks whether you read the file, answer with the categories you
  actually saw (names, counts, value lengths, line structure) and prove the rest:
  `scripts/secret_leak_check.py` scans session transcripts, `state.db` messages
  and logs for every value, printing only key names and hit counts.
- Rotation is owed only when a value actually reached a transcript, a log or a
  provider payload. Say which of those happened rather than blanket-rotating.
  Values sitting in a process environment (readable via `/proc/<pid>/environ` by
  the same user) are a known cost of the mechanism, not a leak.
