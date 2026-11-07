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

`tts_audio_tags` only runs when *both* hold:

- `tts.gemini.audio_tags` is truthy, and
- the TTS model name contains `gemini-3.1` and `tts`
  (`_gemini_audio_tags_enabled`, `tools/tts_tool_providers.py`).

On any other Gemini TTS model it logs a warning per spoken reply and changes nothing — keep
the flag `false` there rather than living with the noise.

## Verification

Aux routes cannot be tested by config readback alone, because failures are swallowed.
Exercise the feature that uses the task and inspect the log; and re-read the whole
`auxiliary:` section after `hermes config set`, since setting one key can materialise
sibling defaults into `config.yaml`.
