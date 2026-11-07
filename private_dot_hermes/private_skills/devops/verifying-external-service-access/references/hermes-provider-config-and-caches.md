# Hermes provider config: disable semantics, cache layers, refresh

Applies to any Hermes install. Read before retiring a provider name, refreshing
model lists, or restoring a config from a backup.

## Provider disable flags are string-literal, not canonical

`providers.<name>.enabled: false` is checked against the **requested provider
string**, before alias expansion. `hermes_cli/runtime_provider.py`
(`_raise_if_provider_disabled`) raises a typed `ValueError` that lets the
resolution ladder advance.

Consequence: the canonical name and each of its aliases are independent keys.
Disabling the canonical name leaves aliases live.

Workflow:

1. Find the canonical name and every alias. Sources: the provider overlay table
   in `hermes_cli/providers.py` (`HermesOverlay` entries plus `_ALIAS_GROUPS`,
   inverted into `ALIASES`), and the picker's own listing.
2. Write one key per spelling.
3. **Re-probe each spelling with a real completion.** Do not infer from the
   config file that a key took effect — a misspelled alias silently does
   nothing.

```bash
hermes config set providers.<spelling>.enabled false
hermes chat -q "Reply with exactly: PONG" --provider <spelling>
```

A blocked name fails with `provider '<name>' is disabled in config
(providers.<name>.enabled: false)`. Anything else answering is a live alias you
missed.

Disabling a provider does not prevent a plugin from registering a **different**
name for the same vendor. Retiring the built-in leaves the plugin's name
working, which is usually the intent.

## Model list caches are layered

| Layer | Path | Written by | Refresh |
|---|---|---|---|
| Picker catalog | `~/.hermes/cache/model_catalog.json` | `hermes model` | `hermes model --refresh` |
| Per-provider endpoint lists | `~/.hermes/provider_models_cache.json` | picker when an API key is present | same |
| Plugin discovery | `<plugin-dir>/../cache/<plugin>/models.json`, via `get_hermes_home()` | the **gateway process** on startup | gateway restart |

Consequences:

- `--refresh` wipes and refetches the picker layers, so a provider you just
  disabled disappears from them. A stale entry in the file is not a live route —
  confirm by request, not by reading the cache.
- **A plugin's own cache is not rebuilt by CLI runs.** Deleting it in a CLI
  process leaves it missing until a gateway process runs discovery. Expect the
  file to reappear minutes later, not instantly.
- A plugin's model list is a **computed intersection** (e.g. live `/v1/models`
  ∩ models.dev metadata requiring tool-calling and zero cost). It drifts between
  refreshes: models appear and drop as the vendor's catalogue and the upstream
  metadata change. Never present it as a stable set, and never assert a model is
  unavailable just because it is absent from one snapshot — ask for it by name
  and probe.

## `hermes model` needs a TTY

It refuses pipes and non-interactive subprocesses. Drive it with a pty when a
script must:

```bash
script -qec "hermes model --refresh" /dev/null < /dev/null
```

The refresh (cache wipe + refetch) completes even if the interactive selection
never finishes — it hangs at the prompt. Verify by cache mtime and file
contents, not by the command's exit code. Expect a `WARNING: your terminal
doesn't support cursor position requests (CPR)` line under `script`; that is
harmless.

## Restoring a config

`hermes config set` / `hermes config unset` rewrite the merged config, so they
do not preserve byte-level layout. To restore the previous value, copy the file
aside **before** the first write and diff against it afterwards rather than
retyping values from memory — reconstruction reintroduces your own test edits as
user settings.

Prefer `hermes config unset <key>` over deleting a nested block by hand: unset
leaves unrelated siblings intact.