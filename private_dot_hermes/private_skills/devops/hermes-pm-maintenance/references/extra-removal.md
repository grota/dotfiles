# Removing a PM extra

PM's extras ledger is append-only (`pm/install.py` `_target_selection`:
`enabled = sorted(recorded ∪ requested)`). `hermes pm install --extra X`
grows it; no CLI flag shrinks it. Removal = build a fresh generation with the
target omitted, then record that selection.

## The sync PM runs

`pm/environment.py` `PythonEnvironment.sync` builds (`--frozen`, one
`--extra` per enabled extra):

```
uv sync --frozen --all-packages --python <pinned-python> --compile-bytecode \
  --extra <each remaining extra>
```

So dropping `kittentts` from `[all, edge-tts, kittentts, telegram]` means
re-syncing with only `--extra all --extra edge-tts --extra telegram`.

## The ledger so the removal sticks

- Read: `pm.lock.Facts(pm.environments.runtime_facts_path())` →
  `packages.venv` holds `extras`, `stamp`, `environment`, `resolved_lock`.
- Build: `pm.packages.Venv.apply(target, explicit=True)` under
  `pm.install._venv_install_lock(patient=True)` — fresh generation via
  `pm.workspace.lock_and_sync`, nothing touched in the live tree.
- Stamp: `Venv.expected_stamp(target)` hashes `uv.lock` + extras + python
  identity + plugin member stamp (`pm/packages.py`).
- Commit: `Facts.record_state("venv", stamp, target, environment=...,
  resolved_lock=...)`. Receipt calls (`record_feature_list`,
  `record_venv_rebuild`) are cosmetic; the `record_state` write is the
  commit.
- Boot gate: `pm.install._runtime_state_matches` compares the recorded
  stamp + environment path before any process loads the venv.

## Verification (isolated interpreter only)

```bash
# anchors gone from the NEW tree (grep the tree, not a find_spec in a
# shell whose sys.path may include the old venv)
ls <new-venv>/lib/python*/site-packages/ | grep -i -E "kitten|misaki|soundfile|torch"

# nothing references them in the lock-backed tree
<new-venv>/bin/python -S -c "import sys; print(sys.path)"

hermes pm status          # feature_list must omit the extra, outcome ok
du -sh <new-venv>        # expect the heavy-closure delta (GBs for ML extras)
```

A `find_spec` returning True after removal usually means the probing process
inherited the OLD venv on `sys.path` (launcher env, `PYTHONPATH`, or running
from the old interpreter) — re-probe with `python -S` or a bare env, not a
second removal attempt.

## Aftercare

Restart the gateway/CLI so they adopt the recorded generation, then
`hermes pm gc` to reap the superseded tree. Keep the pre-change
`facts.json` backup until the new generation has served at least one clean
restart; on failure restore the backup and restart consumers.
