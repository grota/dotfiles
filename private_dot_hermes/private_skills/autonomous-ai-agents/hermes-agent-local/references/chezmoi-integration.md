# Tracking the Hermes home with chezmoi

Rules for putting `~/.hermes` under a dotfile manager. Distilled from a real
setup (chezmoi + gpg).

## What to track, what never to track

Track (small, hand-authored, stable):

- `config.yaml` (settings only — it holds no secrets) and `SOUL.md`
- `memories/MEMORY.md` + `memories/USER.md` — **encrypted** (`chezmoi chattr +encrypted`)
- agent-created skills **only** (never bundled ones: `hermes update` reseeds them
  into every profile, so the tree churns forever)
- plugins you wrote yourself, custom provider scripts (e.g. `tts/langvoice.py`),
  `agent-hooks/`

Never track: `.env`, `auth.json`, `state.db*`, `shared-state.db*`, `kanban.db*`,
`projects.db*`, `sessions/`, `logs/`, `cache/`, `tools/`, `installs/`,
`hermes-agent/` (its own git checkout — `hermes update` owns it), `backups/`,
`state-snapshots/`, `checkpoints/`, `whatsapp/` (link session), `webapp/`,
`pairing/`, `telemetry/`, `*_cache`, `config.yaml.bak*`,
`.skills_prompt_snapshot.json`, `skills/.bundled_manifest`, `skills/.hub`,
`skills/.archive`, `skills/.curator*`, `plugins/.install-metadata.json*`.

**Derive that list — never write it from memory.** Hermes creates runtime files
continuously (pids, heartbeats, spawn ledgers, per-update receipts, provider
caches, `pastes/`, `terminal-sessions/`, `sandboxes/`, `state/`, `runtime/`,
`platforms/`, `install_id`), so any list recalled from experience has holes:

```bash
chezmoi unmanaged | grep '^\.hermes/' | sort   # classify every line, then ignore it
```

Cover atomically-named families with wildcards so new generations cannot leak:
`.hermes/*.lock`, `.hermes/**/*.lock`, `.hermes/*.tmp`,
`.hermes/telegram_update_receipts_*.json`, `.hermes/.provider_models_cache_*.tmp`.
Group the rest by intent in `.chezmoiignore` (secrets / databases-and-history /
gateway-and-runtime-state / caches-and-runtimes / plugins / skills) instead of
appending lines wherever they were noticed.

List the agent-created skills (the ones worth versioning):

```bash
cd ~/.hermes
comm -23 \
  <(find skills -mindepth 2 -maxdepth 2 -type d -not -path 'skills/.*' -printf '%f\n' | sort -u) \
  <(cut -d: -f1 skills/.bundled_manifest | sort -u)
```

Contributed plugins installed from the catalog are **not** yours to version —
`chezmoi forget --force <path>` them and leave the target in place.

## Commands that bite

- **`chezmoi forget` prompts and dies without a TTY** (`could not open a new TTY`).
  Use `chezmoi forget --force <target>`; the target file stays, only the source
  entry goes.
- **`chezmoi add --recursive <plugin-dir>` swallows the plugin's `.git`** (renamed
  `dot_git/` in the source, packfile included). Delete that tree from the source
  and put `**/.git` in `.chezmoiignore`.
- **`chezmoi apply` prompts** for every target that changed since chezmoi last
  wrote it (and for the passphrase of an encrypted source). Verify state without
  applying: `chezmoi status` (empty = target matches source), `chezmoi managed`,
  `chezmoi cat <target>`. Never `apply --force` over hand-edited targets.
- **Agent-written files drift between turns.** The background self-improvement
  review patches skills and memory after a turn, so files added mid-session are
  stale by the time you commit. `chezmoi status` showing `MM` means both sides
  moved: re-`add` the target, then commit.

## Encrypted files (gpg)

`chezmoi chattr +encrypted <target>` fails twice before it works, both for
reasons that are easy to misread as "chezmoi is broken":

1. **Ambiguous recipient.** A name that matches more than one key in the ring
   (`gpg --list-keys "<name>"`) makes gpg pick the wrong one. Pin the key ID in
   both the runtime config and the tracked template:
   ```yaml
   gpg:
     recipient: <16-hex-keyid>
   ```
2. **Untrusted key.** gpg refuses to encrypt to a key with no ownertrust and
   wants a TTY to ask. Set it ultimate with the **full fingerprint**:
   ```bash
   FPR=$(gpg --with-colons --fingerprint <keyid> | awk -F: '/^fpr:/{print $10; exit}')
   echo "$FPR:6:" | gpg --import-ownertrust      # a 16-hex id here is rejected
   ```

Verify: `diff <(chezmoi cat <target>) <target>` is empty, and
`gpg --list-packets <blob>.asc` names the **same key ID** as your other encrypted
files (so one key decrypts the whole repo).

Cost worth stating to the user: memory files are rewritten every session, so each
commit is an opaque blob diff — that is the price of tracking them encrypted.

## Tracked hook scripts

`apply` rewrites a hook script's mtime, and shell-hook consent pins that mtime —
so a restored hook needs `hermes --accept-hooks` again (`hermes hooks doctor`
reports the drift).

## Silencing bundled-skill noise (verified)

`chezmoi unmanaged` lists every bundled skill dir unless something hides it.

- **A negation cannot re-include anything under an ignored parent.**
  `.hermes/skills/*` (ignore the category dirs) plus
  `!.hermes/skills/research/citation-freshness` does **not** work:
  `chezmoi managed` drops to 0 skill dirs, and `chezmoi add` answers
  `chezmoi: warning: ignoring …` followed by
  `parent directory not in source state`. The category dirs must stay visible.
- **Working rule** — ignore every *skill* dir, un-ignore the managed ones, never
  ignore the categories:

```
.hermes/skills/*/*
!.hermes/skills/autonomous-ai-agents/hermes-agent-local
!.hermes/skills/devops/hermes-pm-maintenance
…one line per managed skill…
.hermes/skills/.locks
.hermes/skills/.usage.json
.hermes/skills/.usage.json.lock
```

Cost: one line per managed skill. `chezmoi add` of a new skill refuses with
`chezmoi: warning: ignoring …` until its negation exists — add the line, then add
the skill. One edit, not a dead end.

Name the bundled-only **category** dirs explicitly — `chezmoi unmanaged` reports a
directory whose entire content is ignored, so leaving them unnamed costs a line
per category in the noise list:

```
.hermes/skills/apple
.hermes/skills/creative
.hermes/skills/email
.hermes/skills/media
.hermes/skills/note-taking
.hermes/skills/social-media
.hermes/skills/web
# top-level bundled skills that are dirs, not categories
.hermes/skills/hermes-feature-questions
```

Acceptance test: `chezmoi unmanaged | grep '^\.hermes/'` prints **nothing**
while `chezmoi status` stays empty. Two maintenance costs, both small and both
stated to the user up front: a new bundled category shows as one unmanaged line
until it is named, and a genuinely new hand-authored file still surfaces (a
specific path like `.hermes/tts/langvoice.log` does not hide a future
`.hermes/tts/other.py`).

A blind `chezmoi unmanaged | grep -v '^\.hermes/skills/'` also gives zero noise,
but it hides new files inside your *managed* skills (this reference file surfaced
that way), so prefer the ignore rule.

