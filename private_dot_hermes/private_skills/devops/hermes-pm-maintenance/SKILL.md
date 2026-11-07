---
name: hermes-pm-maintenance
description: "Use when adding or removing Hermes PM venv extras."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, pm, venv, extras, uv, dependency-management]
---

# Hermes PM Maintenance

## When to Use

The user wants to inspect, add, or remove a PM-managed Python extra, reclaim
the disk an unused extra holds, or understand why an install keeps a package
they thought they deleted.

Manage the PM-owned Python venv (inspect recorded extras, add, or remove one)
through PM's own code paths, never with raw pip/uv against the live tree.

## Standing rules

- The extras ledger is append-only: each sync unions recorded extras with
  requested ones. There is no remove flag on the install command.
- Never `uv sync` or `pip install/uninstall` inside the live venv. PM builds a
  fresh generation, then commits a stamp; a hand-mutated tree fails the stamp
  check and gets rebuilt over.
- Back up the install's `facts.json` before any ledger surgery, and restore
  it if the rebuild fails.
- Hold the install lock (stop the gateway or serialize with other installs)
  while rewriting the selection so a concurrent sync cannot race the ledger.
- Verify imports with the new venv's interpreter in isolation. An ambient
  `PYTHONPATH` or inherited `sys.path` leaks the old tree and fakes a
  positive `find_spec`.
- Treat a removed-but-unused extra as a disk-only win. An installed extra
  whose provider is not selected does nothing at runtime.
- See `references/extra-removal.md` for the exact APIs and verification
  commands, and `scripts/rebuild_without_extra.py` for the runnable template.

## Procedure

1. Inspect: read recorded extras via `pm.install.enabled_extras()`, confirm
   with `hermes pm status`, and note the selected venv and its disk size.
2. Decide the target set explicitly (recorded minus the dropped extra).
3. Back up `facts.json` from `runtime_facts_path()` for the repo root.
4. Build: run the rebuild script with the selected venv's python and cwd at
   the repo root. It calls `Venv.apply(target, explicit=True)` under
   `_venv_install_lock`, which runs the real `uv sync --frozen
   --all-packages --extra <each>` in a fresh generation.
5. Commit: stamp via `Venv.expected_stamp(target)` and persist with
   `Facts.record_state("venv", stamp, target, environment=..., resolved_lock=...)`.
6. Verify: `venv_is_current()` true, dropped anchors absent from the NEW
   tree's `site-packages`, `hermes pm status` feature list clean, size drop
   as expected.
7. Restart gateway/CLI so processes adopt the new generation, then
   `hermes pm gc` to reap the superseded generation. GC is AGE-GATED, not
   immediate: superseded generations survive until they are 24h old
   (`collect_generations` `min_age_seconds=86400`), so a rebuild frees no
   space on the first pass. Delete the retired generation dirs by hand if the
   space is needed sooner; they are inert once unselected.
8. On failure: restore the `facts.json` backup and restart consumers; do not
   leave a half-recorded selection in place.

## Pitfalls

- Re-running a plain install after a manual removal re-adds the extra,
  because the ledger still lists it. Rewrite the recorded list, not just
  the tree.
- A long `uv sync` exceeds foreground time caps. Run it as one tracked
  background process and poll/wait it; never start a second copy. The
  terminal tool's `timeout` is MILLISECONDS, not seconds: `timeout=1000`
  kills the command at one second, and the tool reports it as
  "timed out after 1s" regardless of the value you passed. Foreground max
  is 600000. For a command you expect to take minutes, pass a real budget
  (e.g. `timeout=420000`) and only escalate to background if that fails —
  three sub-second timeouts in a row read as "the tool is broken" when the
  actual bug was the unit.
- `uv sync` is declarative with no remove verb. Removing an extra means
  re-syncing with it omitted, plus updating the recorded selection to match.
- Opt-in extras that pull heavy native/ML closures cost gigabytes. Check
  the new generation's size before and after; that delta is the payoff.
- `hermes pm gc` prints THREE unrelated numbers: `removed <n>, kept <k>` is the
  TOOL STORE sweep (`~/.hermes/tools/` binary entries: python, node, ffmpeg),
  while `removed <n> dependency generations` is the venv sweep. A large
  `kept` count with no `dependency generations` removed is normal and is not
  evidence the venv sweep failed.
