# Profiles, gateways and per-person agents

A profile **is** a separate `HERMES_HOME`. `~/.hermes` is `default`; every other
profile is `~/.hermes/profiles/<name>/` carrying `config.yaml`, `.env`, `SOUL.md`,
`memories/`, `state.db`, `skills/`, `plugins/`, `cron/`, `logs/`,
`gateway_state.json`. A directory counts as a profile only when it holds an
identity file (`config.yaml`, `.env`, `SOUL.md`, `profile.yaml`, `auth.json`,
`state.db`).

```bash
hermes profile create coder            # blank; bundled skills seeded; alias created
coder setup                            # keys, model, gateway tokens (interactive)
coder chat                             # or: hermes -p coder chat  (-p works anywhere)
hermes profile list | show coder | use coder | delete coder     # delete: type name, --yes to skip
hermes profile describe coder --set "..."   # kanban routing
```

Every profile gets a real command alias at `~/.local/bin/<name>`, so
`coder config set …`, `coder skills list`, `coder doctor` are all
`hermes -p coder …`. `hermes profile use coder` is a sticky default (prompt shows
`coder ❯`); `use default` reverts. `default` cannot be deleted or truly renamed —
renaming it only sets a display name.

## What is and is not isolated

Isolated: config, `.env` secret scope, memory (both files), sessions and FTS,
skills, plugins, cron, gateway state, logs, approvals, toolsets.

Not isolated — say these out loud before anyone plans on privacy:

- **No sandbox.** Same OS user and filesystem; a profile's agent can still read
  another profile's files if asked. What is enforced: the media-delivery denylist
  blocks attaching another profile's `.env`/`auth.json`/`state.db`/transcripts to
  a reply, authorization and allowlists are read from the bot-owning (transport)
  profile, and a default-profile "always allow" never pre-approves a sibling's
  commands.
- **`HOME` stays the real home** (so `~/.ssh`, `gh`, `npm` credentials are
  shared) unless that profile sets `terminal.home_mode: profile`, which then
  needs its own initialized `~/.ssh`/`~/.gitconfig`/CLI logins.
- **OAuth logins are shared** from root `auth.json` (Anthropic/OpenAI/xAI
  refresh tokens are single-use; a copy revokes the other). Static API keys are
  per-profile. A profile gets its own login with `hermes -p <n> auth add <p>`.
- `terminal.cwd` is the starting directory; `cwd: "."` means the launch dir, not
  the profile dir.

## Gateway topology: one host gateway, not one per profile

Multiplexing is the default now (`gateway.multiplex_profiles: true`; unset
resolves on and the value is written into the default profile's config). One
process — whichever profile launched it — serves every live profile under
`profiles/` and rescans on create.

- `hermes -p <name> gateway start|install` **refuses with exit 78**: "Profile
  '<name>' does not get a gateway of its own". Do not coach a new profile through
 `gateway start` — it is already served.
- `hermes gateway status` lists the served set. `hermes -p <n> gateway run` while
  the host is live **attaches** (prints PID + served set, exits 0; exit 75 under a
  supervisor so the unit retries). `gateway start --all | restart --all` mean the
  one host multiplexer.
- `gateway.standalone: true` in a profile is a temporary compatibility shim, not
  a topology to build on.
- Which profiles get served: every live named profile except `standalone: true`
  ones. Blockers: a secondary still running its own gateway, a duplicate bot
  credential, or a port-binding platform with no `/p/<profile>/` ingress.

Under the multiplexer, ask **which profile is the turn, and which profile is the
door** — they are often different owners:

- **Runtime profile** (the one the turn runs as) supplies provider keys, bot
  tokens, `${VAR}` refs (never falling back to default's value), model, memory,
  skills, SOUL, terminal/sandbox settings, command approvals, redaction.
  Fail-closed, not inherited.
- **Transport profile** (the one whose bot received the message) supplies
  admission: allowlists and **slash-command gating**. A shared-bot route keeps
  the receiving bot's gate even though the answer runs as another profile —
  `gateway/slash_access.py::policy_for_runner_source` takes the owner from
  `identity.transport_profile`, never from the routed profile. The docs phrase
  "the profile whose bot received the message" is literal; assuming the target
  profile's `allow_admin_from` governs a routed turn is wrong.

## Channels belong to a profile

- Each profile needs its **own** bot token; a token lock blocks reuse and names
  the conflicting profile.
- WhatsApp pairs **per profile** on its own bridge session and port:
  `hermes -p <name> whatsapp` (QR). An unpaired profile is skipped as
  `whatsapp_unpaired` rather than breaking the host's bridge.
- Inbound-port platforms (Cloud API, Teams, Twilio, LINE, Feishu, WeCom) get a
  port-less adapter the default listener forwards to under `/p/<profile>/`.
- `gateway.profile_routes` (declared on the default profile) routes specific
  guild/chat/user to a profile when communities share one token.

### One WhatsApp account, several people

Pairing is a profile property, so `hermes -p <n> whatsapp` links a **second
WhatsApp account** (a second number) as a device — it does not add a second
person to the existing account. Establish which model the install uses before
advising anything:

- `platforms.whatsapp.home_channel` names the *chat* the bot last treated as
  home; `sessions.user_id` for `source='whatsapp'` lists the *senders*. Several
  senders arriving on one account is normal and needs no second number, no
  second bridge, no second pairing.
- To separate those people without another number, route by sender identity on
  the **default** profile:

```yaml
gateway:
  multiplex_profiles: true
  profile_routes:
    - name: rosa-dm
      platform: whatsapp
      user_id: "34600111222@s.whatsapp.net"
      profile: rosa
```

Matching is conjunctive and `user_id` is the most specific discriminator
(user_id 16, thread_id 8, chat_id 4, guild_id 2). WhatsApp numbers, JIDs and LIDs
are collapsed through `expand_whatsapp_aliases`, so a route written on the number
still matches when the inbound source carries an `@lid`. Leaving `bot_profile`
unset means the default profile's bot — what a shared bot wants.

**Leave that platform disabled in the target profile.** The route makes the
profile a *shared-bot satellite* only when it has no adapter of its own *and* an
enabled `profile_routes` entry targets it through the default bot
(`gateway/authz_mixin.py::_is_shared_bot_satellite`); it then drains outbound
through the primary's adapters, which is exactly why one bridge serves both
people. Enable WhatsApp there and it becomes a credential boundary with its own
unpaired bridge (`whatsapp_unpaired`), and the route stops delivering. Its
`.env` still needs its own provider keys: the transport may be borrowed, the
credentials never are.

## Seeding a profile

- `--clone` (= `--clone-from`) copies `config.yaml`, `.env`, `SOUL.md`, the whole
  `skills/`, `plugins/` with install records, the active memory provider's config,
  and **both memory files** (memory is treated as identity). Everything else —
  sessions, `state.db`, cron, skins, logs — starts empty.
- `--clone-all` copies the whole profile root **minus** per-profile history
  (`state.db` + `-wal`/`-shm`, `sessions/`, `backups/`, `state-snapshots/`,
  `checkpoints/`, `cron/`, `webapp/` sign-in state), plus — only when the source is
  `default` — infrastructure (`hermes-agent/`, `node_modules/`, `bin/`, `node/`,
  `.worktrees`, `profiles/`, managed model/runtime trees: tens of GB, re-resolved
  from the default root), gateway runtime files (`gateway.pid`,
  `processes.json`, bot-desktop pids/lease) and single-use OAuth grants. It is a
  **superset** of `--clone` on user state, adding `skins/`, `logs/`, `plans/`,
  `workspace/`, `vault/`, `auth.json` API-key rows and the full `memories/` tree.
- Both drop history and cron; both strip messaging channels. `--clone-all` only
  *reads* smaller because its help and output enumerate the exclusions ("excluding
  session history, cron jobs, backups, snapshots") while `--clone` enumerates
  inclusions.
- Messaging channels are **never** cloned (tokens, allowlists, `platforms:`,
  pairing state) unless `--clone-channels`, which refuses when a multiplexer
  already serves the source.
- Therefore: creating a profile for a **different person** must not hand them the
  source's `USER.md`. Either create blank, or `--clone` and then delete
  `memories/MEMORY.md` + `USER.md`; write their `SOUL.md`, set their model/tools,
  pair *or route* their channel, done.
- Their past conversations stay in the old profile's `state.db`; move them with
  `hermes sessions export …` + `hermes -p <n> sessions import` if continuity
  matters.
- `hermes update` pulls code once and syncs bundled skills into every profile
  without overwriting modified ones.

## Sharing config: symlinks, deltas, dotfiles

- Hermes's atomic writer is **symlink-preserving**: `utils._publish_path()`
  resolves a link to its real file and stages the temp beside it, so
  `hermes config set`, the memory tool and `.env` writes update the target and
  leave the link in place. A managed symlink is not silently replaced by a
  regular file.
- That still does not make symlinks a way to avoid per-profile maintenance: a
  link makes two profiles share **one file**. `rosa config set model.default X`
  then edits default's model; a shared `.env` re-imports bot tokens and
  allowlists (the collision the channel strip exists to prevent); a shared
  `memories/` gives two writers one store — the never-two-processes-on-one-home
  failure. Link a profile's file into a *dotfiles repo*, never into another
  profile.
- A profile's `config.yaml` needs only its **deltas**: `load_config()` merges
  `DEFAULT_CONFIG` + the file, so ~20 lines (model block, memory limits, a couple
  of gateway flags) is a complete config. Never hand over a copy of a
  2,000-line file that is mostly commented defaults.
- Versioning a Hermes home: keep `config.yaml`, `SOUL.md`, `memories/*.md`,
  hand-written `plugins/`, custom scripts, `cron/jobs.json`. Ignore `state.db*`,
  `sessions/`, `logs/`, `cache/`, `checkpoints/`, `backups/`, `telemetry/`,
  `auth.json`, `.env`, `whatsapp/`, `webapp/`, and the runtime trees (`tools/`,
  `installs/`, `hermes-agent/` — the checkout has its own git). Of `skills/`,
  version only agent-created ones; `hermes update` re-seeds bundled ones.
- With a copy-based dotfiles manager, review its diff before applying: Hermes
  mutates `config.yaml` itself (multiplex flag, "always allow" approvals,
  `/model` switches).

## Pitfalls

- **Never point two processes at one `HERMES_HOME`.** Both write memory
  automatically and each loads the other's writes at session start, compounding
  state nobody authored. Shared memory needs an external provider, not a shared
  home.
- **Bot Mode is presentation, not a different isolation model**: every bot is a
  profile with roster metadata and a pinned Bot Chat; not every profile is a bot.
- **Don't make a profile the sticky default as a side effect** of testing —
  `hermes profile use` changes what every bare `hermes` command targets.
