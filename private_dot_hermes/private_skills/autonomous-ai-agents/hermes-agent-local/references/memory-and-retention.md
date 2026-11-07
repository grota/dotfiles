# Memory, sessions & retention

"What memory does Hermes have, how do I list it, how do I delete it, why did it
forget?" is four questions wearing one word. Answer with all four layers —
the user means layer 1, but the fix is often layer 2 or 3.

| Layer | Holds | Bound by default | Cleanup |
|---|---|---|---|
| Built in: `MEMORY.md` + `USER.md` | agent notes / user profile | 2,200 + 1,375 chars | agent's `memory` tool, `hermes memory reset`, `hermes journey delete` |
| Session history `state.db` | every full transcript, FTS5-indexed | unbounded — auto-prune ships **off** | `hermes sessions prune` / `archive` / `optimize` |
| In-context (compression) | the live window | 85% gateway hygiene, 50% agent compressor | `/compress`, `/new`, micro-compaction |
| Skills | learned procedures | count, not chars | curator: stale → archive |

## Layer 1 — built-in stores

Files live in `$HERMES_HOME/memories/` (`~/.hermes/memories/` on `default`), one
file per target, injected into the system prompt as a **frozen snapshot at
session start**. Caps: `memory.memory_char_limit` (2200) and
`memory.user_char_limit` (1375); raising one is a config write, no restart.

- The tool has `add` / `patch` / `remove` and **no `read`** — content already
  arrives in the prompt. `patch` replaces one span inside an entry
  (substring match); `replace` was removed because models used it as a
  find-and-swap and wiped multi-fact entries.
- There is **no auto-compaction**. An over-limit write returns an error with
  `current_entries` and the exact overflow, and the limit is re-checked only on
  the final result of an `operations` batch — so the correct response is one
  batch that frees space *and* adds the entry, not a retry.
- Exact duplicates are rejected; entries are scanned for injection /
  exfiltration patterns and invisible Unicode before acceptance.
- Both `memory_enabled` and `user_profile_enabled: false` drop the tool and its
  prompt block entirely; disabling only one narrows the schema to the surviving
  target.

### Listing and deleting

| Want | Do |
|---|---|
| see entries | `cat $HERMES_HOME/memories/MEMORY.md $HERMES_HOME/memories/USER.md` — plain text, hand-editable |
| delete one fact | a `memory` call with `remove` + a unique substring (no need for the full entry) |
| delete one chunk by id | `hermes journey list`, then `hermes journey delete memory:<source>:<index>:<fingerprint>` (`journey edit <id>` opens it in `$EDITOR`) |
| wipe a store | `hermes memory reset --target {all,memory,user} [--yes]` — irreversible |
| gate future writes | `memory.write_approval: true`; then `/memory pending|approve <id>|reject <id>|approval on|off` |

`/memory` is **only** the approval gate — it does not list the stores. Background
self-improvement writes are tagged `[auto]`; a staged patch/remove pins the
entry it targets and is refused if that entry changed meanwhile.
`display.memory_notifications: off|on|verbose` controls the chat line, not the
write.

`hermes journey` (aliases `learning`, `memory-graph`) renders the same data as a
timeline; the desktop `/journey` panel edits and deletes nodes directly. Skills
show up there once they carry a learning signal.

## Layer 2 — session history (`state.db`)

One SQLite file with FTS5 and every transcript; `~/.hermes/sessions/` holds the
JSONL transcripts and routing index. `hermes sessions stats` gives sessions,
messages, size per source. Auto-prune is **off** by default — nothing deletes
history unless asked.

```yaml
sessions:
  auto_prune: true          # off unless set
  retention_days: 90        # whole days >= 0; negative/missing is refused + logged
  vacuum_after_prune: true
  min_vacuum_interval_days: 30
  min_interval_hours: 24
```

- Bare `hermes sessions prune` = ended sessions inactive >90 days. **Any filter
  disables that implicit default**, so add a time flag when filtering by source
  or model. `--dry-run` previews; `--yes` skips confirmation; `--newer-than /
  --before / --after` accept `5h`, `30m`, `2d`, `1w`, bare days, or ISO.
- Only *ended* sessions are prunable. A compression-split conversation is pruned
  as one unit. Each sweep also closes orphaned open sessions from state-owned
  sources (`cli`, `cron`, `kanban`, `acp`, `api_server`, `subagent`, `tool`) so
  they can age out later.
- `hermes sessions archive` takes the same filters and soft-hides instead.
- VACUUM after a prune only fires when ≥`min_vacuum_interval_days` have passed
  **and** >25% of pages are reclaimable — a dense DB is left alone.
- Low-disk nudge: with `sessions.auto_prune` unset, a nearly full disk triggers
  a one-time `/autoprune on|off|later` prompt (CLI/TUI/desktop, or the gateway's
  home channel).

**Non-destructive first.** `hermes sessions optimize` merges FTS5 segments and
VACUUMs without touching data; `optimize-storage` migrates the index to the
compact layout. Recommend those before any prune, and say plainly when history
is not the space problem.

### Pitfall: the DB refuses while anyone holds it

`optimize` and `prune` (without a running gateway) refuse when another Hermes
process has `state.db` open, printing each PID and its files. **The session
asking is itself a holder**, so from inside a TUI/CLI turn the command always
refuses — never promise it will run. Hand over the recipe: stop the gateway
(`hermes gateway stop`, plus quit Desktop/dashboard/cron), then re-run. The
refusal exists because rewriting under a live writer is how sessions end up
failing with the retired `state.db-wal` error; `--force` is the documented
escape hatch, not the default answer.

## Layer 3 — the context window

Two compression layers: gateway **session hygiene at a fixed 85%** of context
(safety net for overnight messaging accumulation) and the agent's
`ContextCompressor` at **50%** (`compression.*`, `tail_mode: lean` keeps a
clamped 10K–25K tail plus a verbatim session log and identifier index).

- `/compress` (alias `/compact`) = manual, `here [N]` keeps N turns, `--preview`
  shows the result. `/new` (alias `/reset`) is the real boundary: it re-reads
  the memory snapshot and makes the forget → recall → `session_search` loop work.
- `compression.micro_compact: true` is opt-in: one exchange absorbed per turn,
  steady cost instead of one stall, but it rewrites sent history every turn and
  therefore breaks the prompt-cache prefix. User messages are never compacted.
- `context.engine: <plugin>` swaps the compressor (e.g. a lossless engine);
  plugin engines never auto-activate.

## Layer 4 — skills (the curator)

`active → stale (14d unused) → archived (30d unused, moved to
`skills/.archive/`)`; **it never auto-deletes**, hub-installed skills are
off-limits, and bundled ones are only prunable with `curator.prune_builtins:
 true`. `hermes curator status | run --dry-run | pause | pin <skill>`. First run
seeds `last_run_at` and defers one full interval, so a fresh install is not
pruned on first tick.

## External providers

`hermes memory setup | status | off`. Bundled: retaindb, byterover; catalog:
honcho, hindsight, supermemory, mem0, openviking, holographic. One active at a
`time, running **alongside** the built-in files (never replacing them), each
with its own retention. `memory.prefetch_spill_enabled` opts into head/tail
previews for oversized recall; default cap is 10× `hooks.output_spill.max_chars`
(at least 100,000 chars).

## Verification probes for this domain

```bash
hermes memory status                  # built-in on/off, active provider, plugins
hermes config get memory              # limits, write_approval, nudge_interval
ls -la "$HERMES_HOME/memories" && wc -c "$HERMES_HOME"/memories/*.md
hermes sessions stats                 # sessions / messages / size per source
hermes curator status                 # active/stale/archived counts, interval
```

**The usage header in the system prompt is a frozen snapshot.** After raising a
limit or saving an entry, the prompt still shows the old `n/limit` and the old
entries until a new session starts; the tool enforces the new limit immediately.
Quote the files, `hermes memory status`, or a fresh tool result — never the
header — when reporting current memory state.
