---
name: hermes-plugin-development
description: "Write, enable and debug Hermes provider plugins."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [plugins, providers, tts, stt, browsers, delegation, hermes]
---

# Hermes native plugins and provider backends

Hermes ships a plugin system whose main use is registering a *backend* for an existing tool
(TTS, STT, browser, terminal, delegation, secrets). The contract is small, the failure modes
are silent, and `hermes plugins doctor` does not tell you whether the provider actually landed.

## When to Use

- The user wants a new speech engine, transcription backend, browser cloud, terminal backend,
  delegation route or secret source that Hermes does not ship.
- An existing provider cannot express something the upstream API supports (extra request
  fields, a catalog, PCM streaming).
- A plugin loads but the tool still uses the old backend, or enabling it changed nothing.

## Pick the cheapest mechanism that works

1. **Config only** when a built-in provider covers it — no plugin, no script.
2. **`type: command` provider** when the backend is a shell command:
   `tts.providers.<name>: {type: command, command: "… {input_path} {output_path}"}`. Lives
   entirely in the user's config + a script they own, survives updates, cannot collide with a
   built-in name. Limitations: fixed placeholders, no catalog, no PCM streaming, no
   per-provider Python API.
3. **Native plugin registering a provider ABC** when you need a real client: streaming, a voice
   or model catalog, runtime knobs, request shapes the built-ins never send.

## Layout and manifest

```
~/.hermes/plugins/<plugin-name>/
  plugin.yaml        # manifest_version: 1, name, kind: standalone, version, capabilities: []
  __init__.py        # def register(ctx): ctx.register_tts_provider(Provider())
  provider.py        # the ABC subclass
  README.md          # every config key, mapped to the upstream capability
  tests/selftest.py  # plain-assert suite (no pytest in the bundled venv)
```

`kind` is one of `standalone | backend | exclusive | platform | model-provider`; an unknown
value silently degrades to `standalone`. Model-provider plugins are the exception to the
entrypoint rule — they register a `ProviderProfile` at import; every `ctx.register_*_provider`
hook uses `def register(ctx)`. Starter files: `templates/plugin.yaml`, `templates/__init__.py`,
`templates/provider.py`.

## Enable, then prove registration

```
hermes plugins enable <name>        # gateway reloads plugins live, says so in the output
hermes plugins doctor <name>        # manifest + import + registration contract
```

**Doctor's `registrations: 0 tool(s), 0 hook(s)` is not a failure** for a provider-only plugin —
providers are neither tools nor hooks. Prove it in the registry instead:
`scripts/verify_registration.py <name>` prints the provider object plus `is_available()`,
`streams_pcm`, `stream_sample_rate` and `voice_compatible`. A plugin can load cleanly and still
never dispatch if its `name` collides with a built-in (the registry logs a warning and ignores
it), so this check is the one that matters.

## Provider ABC details that bite

- `name` must be unique and must differ from every built-in name; a collision is logged and
  dropped, and the tool then falls back to its default provider with no other symptom.
- `is_available()` runs on every picker paint and every dispatch: no network, no exceptions.
- `voice_compatible` defaults to **False** — without overriding it the gateway ships an audio
  file instead of a Telegram voice bubble.
- `streams_pcm = True` needs a finite `stream_sample_rate >= 1`; a bad rate falls back to
  per-sentence synthesis silently.
- `stream()` may be called concurrently (the speaker prefetches several sentences): keep it
  stateless or lock it.
- `synthesize()` must **raise** on failure — the dispatcher turns the exception into its error
  envelope — and must write `output_path`. Its `format=` argument is **not** the destination
  container: `_dispatch_to_plugin_provider` passes `tts.output_format` (global, default `mp3`),
  and the path Hermes hands over always ends `.mp3` because `_NATIVE_OPUS_PROVIDERS` excludes
  plugin names. With `voice_compatible = True` Hermes then transcodes to Ogg/Opus itself in
  `_finalize_voice_delivery`, so an mp3-writing plugin pays two ffmpeg passes per reply: return
  a sibling `.ogg` path and the second pass is skipped. A container that disagrees with the path
  is only repaired for `.ogg` paths (`_repair_ogg_container`), so foreign bytes in a `.mp3` path
  reach ffmpeg unchecked.
- Built-in names always win, and a `tts.providers.<name>: type: command` entry wins over a
  plugin of the same name. Config is treated as more specific than an install.

## Runtime-tunable config (no restart)

Read config on **every call**, never at import: `hermes_cli.config.load_config_readonly()` is
cached on the file's signature (`config_cache_version`), so an edit is visible to the next call.
Layer the resolution and document the order in the README:

```
built-in defaults  <  config.yaml section  <  per-call kwargs  <  a flat JSON override file
```

The last layer is what makes "change it at runtime" real for a user who does not want to touch
`config.yaml`, and it lets a CLI helper pin one knob for a single render. Write schema-less
nested keys with `hermes config set --force <path> <value>`; comments already in the file
survive later `config set` writes, so documenting a provider block inline is safe.

## Testing without pytest

The bundled venv has no pytest. Write `tests/selftest.py` as plain `assert`-style checks that
print `PASS`/`FAIL` per case and exit non-zero.

- Loading `provider.py` by path breaks `from . import api`: register a synthetic package first
  (`m = types.ModuleType("pkg"); m.__path__ = [dir]; sys.modules["pkg"] = m`) and then
  `spec_from_file_location("pkg.provider", …)`. Plugin directory names may contain hyphens,
  which are legal for Hermes and not for `import`.
- For audio/image/file paths, generate a deterministic fixture (a sine of known length) and
  assert with `ffprobe` on duration/format — never by listening or eyeballing.
- Mock at the transport boundary (`api._post = lambda …`). A synthetic payload proves your
  assumption; keep one **captured** real response on disk and replay it through the parser,
  because event/SSE/JSON shapes drift from what the docs show.

## Pitfalls

- **A key in your `DEFAULTS` dict and your README is not a key anyone reads.** Grep the plugin for
  reads of the key before describing its behaviour to the user: an unused knob is silent — no
  error, no log, defaults always win — and "the README says it strips tags" then becomes a false
  claim about the code.
- **The chunk cap is resolved by Hermes core, not by the plugin.** `_resolve_max_text_length`
  looks in `tts.<provider>.max_text_length` — *not* `tts.providers.<provider>.max_text_length`,
  where a provider block temptingly puts it — and an unrecognised (plugin) provider name falls
  through to a 4000-character cap. Splitting runs before dispatch, so N chunks are N vendor
  requests against the quota, and a plugin that ignores `text` (script/turns mode) renders its
  script once per chunk into a file that is then concatenated.
- `capabilities:` as a mapping is ignored with a warning — it must be a **list**.
- `hermes plugins enable/disable` reloads plugins live; hand-editing `plugins.enabled` needs a
  gateway restart.
- Never cache the API key at import: resolve it per call (process env, then the profile
  dotenv), or a key added after the plugin loaded stays invisible until a restart.
- Do not leave a quota-bound backend as the default while you iterate. Probes, retries and
  chunking all spend quota, and the resulting 429 reads like a broken plugin.
- An upstream that returns a different container than requested (or clamps a sample rate) must
  drive decoding from the **reported** mime type, not from the requested one.

## Reference

- `references/provider-registration.md` — every `ctx.register_*_provider` hook, its ABC, the
  config key that selects it, and the dispatch rules.
- `scripts/verify_registration.py` — registry probe used to prove a provider landed.
