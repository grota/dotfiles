# Auxiliary tasks — per-task model routing (`auxiliary.<task>`)

Hermes routes background LLM work (vision descriptions, compression summaries, titles, the
approval classifier, review, TTS tag rewriting) through separate model blocks under
`auxiliary.<task>`, not through the main chat route. Read the block with
`hermes config get auxiliary.<task>`.

## Block shape

Every built-in task is built by `_aux()` in `hermes_cli/config_defaults_auxiliary.py`:

```yaml
auxiliary:
  <task>:
    provider: auto        # "auto" | "" | main | a provider name | custom[:<name>]
    model: ""             # "" = follow the route; else any model id, unvalidated
    base_url: ""          # overrides the provider's endpoint (with api_key)
    api_key: ""
    timeout: 30
    extra_body: {}        # forwarded verbatim as OpenAI-compatible fields
    reasoning_effort: ""  # none|minimal|low|medium|high|xhigh|max|ultra
```

`review` and `title_generation` carry extra keys (`api_mode`, `prefer_fast_model`,
`language`, `enabled`, `model_upgrade_enabled`). `fallback_chain:` and `max_concurrency:`
are accepted on long-running tasks such as `compression`.

## What `provider` may be (`agent/auxiliary_client.py::resolve_provider_client`)

Resolution order — first match wins:

1. `auto` (or `""`): follow the main chat route, resolved live. `main` is an alias for the
   main provider.
2. Dedicated branches: `openrouter`, `nous`, `openai-codex`, `xai-oauth`, `custom`.
3. A named custom provider: `custom:<name>`, or a bare name matching an entry under
   `providers:` in `config.yaml`.
4. `azure-foundry`.
5. `PROVIDER_REGISTRY` in `hermes_cli/auth.py` (~79 names: `gemini`, `deepseek`,
   `anthropic`, `openai-api`, `xai`, `nous`, `vertex`, `bedrock`, `minimax`, `nvidia`,
   `novita`, `zai`, `qwen-oauth`, `lmstudio`, …) plus plugin profiles in
   `plugins/model-providers/*`.
6. Aliases are normalised first (`codex` → `openai-codex`).

Names that look obvious but are NOT built-in providers on a stock install: `groq`,
`mistral`, `cerebras`, `together`, `ollama` (`openrouter` has its own branch rather than a
registry entry). Reach those through `custom` + `base_url` + `api_key` instead of pinning the
bare name and hoping.

## What `model` does

- `""` is not "no model": it falls back to that provider's registered default aux model,
  then to your main chat model. Pinning a provider while leaving `model: ""` therefore sends
  your *main* model slug to the *new* provider — usually the wrong pairing. Pin both.
- Any other string is passed through unvalidated. A bad slug fails upstream, never locally.

## Failure mode: silent, by design

`_resolve_registry_branch` logs `unknown provider` once at debug and returns `(None, None)`;
callers wrap aux calls in `try/except` and fall back. For TTS tag rewriting
(`tools/tts_tool_providers.py::_rewrite_with_auxiliary_model`) the fallback is the untagged
transcript. So a typo'd route degrades quietly to "feature off" — when an aux-driven feature
does nothing, read the debug log before re-reading the vendor docs.

## The TTS tag task specifically

Two different switches turn tag rewriting on:

- **built-in Gemini provider**: `tts.gemini.audio_tags` truthy *and* the model slug
  contains `gemini-3.1` and `tts` (`_gemini_audio_tags_enabled`,
  `tools/tts_tool_providers.py`). On any other Gemini TTS model it logs a warning per
  spoken reply and changes nothing — keep the flag `false` there.
- **a TTS provider plugin that calls `_rewrite_with_auxiliary_model` itself** (the
  local `gemini-custom` does, because 3.x interaction models want *angle-bracket*
  tags while the 3.1 prompt emits square brackets). Then the plugin's own flag
  decides and the model slug is irrelevant.

Whichever caller is in play, the system prompt must match the target model's tag
syntax. Make the prompt overridable from config and print the built-in default next
to it as a commented block that is *valid YAML once uncommented* (see
`references/local-config-and-providers.md` for the assertion that guarantees it).

Key naming decides whether a pinned route works at all: `provider: gemini` fails
with *"no API key was found. Set the GOOGLE_API_KEY environment variable"* when the
credential exists only as `GOOGLE_GENERATIVE_AI_API_KEY` — the aux resolver wants the
canonical name. `provider: auto` needs no name, but only resolves inside a live agent
process, which passes the main runtime into the call; from a bare script it answers
*"main provider <id> is unavailable and no fallback_chain / fallback_providers is
configured — refusing to guess"*. Route aux tests through the feature itself.

Small models decline to act, and that is not a failure: gpt-5.4-mini inserts
`<exhales>` after a startle and leaves neutral prose untouched. Loosen the prompt
before re-plumbing the route, and budget ~1.5-4 s per request (once per chunk, not
once per reply).

## Verification

Aux routes cannot be tested by config readback alone, because failures are swallowed.
Exercise the feature that uses the task and inspect the log; and re-read the whole
`auxiliary:` section after `hermes config set`, since setting one key can materialise
sibling defaults into `config.yaml`.

For tag rewriting, make degradation visible and measurable:

- log a warning when the rewrite returns the text unchanged (*"tags requested but the
  auxiliary `tts_audio_tags` rewrite returned the text unchanged; speaking it
  untagged"*) — a silent fallback looks identical to a model that declined;
- `~/.hermes/gemini-tts-usage.jsonl` records `chars` per synthesis, so a value larger
  than the text you sent proves tags were inserted *in that call*; equal length means
  the route failed or declined.
