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
  holds that key. Read the dotenv file (`~/.hermes/.env`) or the daemon's
  `/proc/<pid>/environ`, and filter by name not line:
  `env | cut -d= -f1 | grep KEY` (a case-insensitive grep also matches values —
  PATH entries mention install dirs, not credentials).

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
