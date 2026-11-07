---
name: multilingual-tts-voice-switching
description: "Hermes TTS: providers, models, voices, languages."
version: 1.1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [tts, voice, language, edge-tts, gemini, telegram]
---

# Per-message language TTS voices

Hermes has ONE global TTS voice per profile (`tts.<provider>.voice`), so a single
English-default voice reads Spanish/French/Italian text with a foreign accent. Hermes
core does **not** switch voices by language.

## When to Use

- The user reports the spoken reply in their language carries a foreign accent, or asks for TTS
  in Spanish, Italian, French, Portuguese or German.
- Choosing, switching or auditing a Hermes TTS provider or model (`tts.provider`,
  `tts.<provider>.model`, `tts.gemini.*`).
- A spoken reply sounds wrong, silent, clipped, or arrives as a file instead of a voice bubble.

Do not patch core (an update overwrites it). Use a `type: command` provider — a script
the user owns that detects the language and renders with the matching voice.

## Recipe

1. Write the renderer, e.g. `~/.hermes/tts/langvoice.py`, taking `<input_path> <output_path>`:
   - read the text file,
   - score languages with stopword lists + character cues (`ñ`, `¿`, `ã`, `ç`, `è`, `ä`),
     keep a sticky `last_lang` file for tiny/near-tie inputs,
   - call `edge-tts --file INPUT --voice VOICE --write-media OUTPUT --no-progress`,
   - log `{lang, voice, chars, scores}` to a JSONL file — that log is how you verify.
2. Register it (schema-less keys need `--force`):
   ```
   hermes config set tts.provider langvoice
   hermes config set --force tts.providers.langvoice.type command
   hermes config set --force tts.providers.langvoice.command "python3 /home/USER/.hermes/tts/langvoice.py {input_path} {output_path}"
   hermes config set --force tts.providers.langvoice.format mp3
   hermes config set --force tts.providers.langvoice.voice_compatible true
   ```
3. Verify end to end by calling `text_to_speech` once per language and reading the log line
   (`lang`, `voice`) — not by assuming the config took effect.

## Pitfalls

- `write_file` can collapse `"""` triple-quoted blocks into `"` and break the script; use
  `("a b " "c d").split()` implicit concatenation for word lists.
- `edge-tts` lives in the Hermes install venv; resolve with `shutil.which`, fall back to a
  walk over `~/.hermes/installs/*/venv/bin`, never hardcode the hashed path.
- Output format comes from the output path suffix, else `format:`; `voice_compatible: true`
  is what makes the gateway ship a Telegram voice bubble instead of a file.
- Detection must handle code-switching (Spanish prose with English tech terms, English prose
  with Spanish proper nouns) — that is the common case, not clean monolingual text.
- Verify a provider switch from the tool result, not from the config: `text_to_speech` returns
  `provider: <name>` alongside the file path. Config readback only proves the YAML changed.
- Gemini audio tags are gated on the MODEL, not on the flag: the rewrite runs only when the TTS
  model name contains `gemini-3.1` and `tts` (`_gemini_audio_tags_enabled` in
  `tools/tts_tool_providers.py`). On `gemini-2.5-*` the flag costs a warning on every spoken
  reply and changes nothing, so leave `tts.gemini.audio_tags: false` there. Any rewrite failure
  — bad aux route, empty reply, timeout — silently falls back to the untagged transcript.
- To A/B a vendor voice yourself, take the API key from the Hermes dotenv file: keys are
  stripped from the environment handed to tool subprocesses, so `env | grep KEY` shows nothing
  even when Hermes is authenticated and working.

## Alternatives that need no script

Providers whose API auto-detects the input language: Gemini TTS, ElevenLabs multilingual v2,
OpenAI `gpt-4o-mini-tts`, Mistral Voxtral. xAI is the only one with an explicit
`tts.xai.language` field (BCP-47 or `"auto"`).

Decision rule, learned the hard way: auto-detect solves *language*, not *native accent per
language* — one voice renders 130 languages and every non-base language carries a residue of
the voice's original accent. ElevenLabs is the worst case (accent baked into the chosen voice),
Gemini the best (a second-language residue at most). Per-language native voices (the script)
win on accent purity but change "person" between languages, which some users dislike more
than the residue. Ask before choosing.

**Keep both.** Leave the `tts.providers.<name>` block in place when switching
`tts.provider` to a built-in — the script then stays configured and callable, and switching
back is one `hermes config set tts.provider <name>`. Never delete the user's working fallback
because they picked a different default.

## When the built-in provider is not enough

The Gemini adapter cannot send `speech_metadata`, `response_format`/`mime_type`, or a voice
library id, so 3.8's style control, Castilian library voices and raw PCM streaming are
unreachable through `tts.provider: gemini` whatever the config says. The fix is a provider
plugin, not more config: contract, layout, registry verification and the plain-assert test
recipe live in `hermes-plugin-development`. A plugin provider also re-reads its own config on
every call, which is what makes per-render knobs (voice, style, format) change without a
restart — something a built-in provider cannot do.

## Gemini TTS quotas (bites immediately)

Free-tier limits on the TTS models are per-model and tiny: `gemini-3.8-flash-tts`
allows **3 requests/minute and 10 requests/day** (probe scripts burn the daily
aliquot in minutes, and the 429 names the model, not the caller). `gemini-2.5-pro-preview-tts`
is `limit: 0` on a free key. Plan a daily-driver voice that costs nothing (Edge)
and keep a keyed engine for special renders; never leave a quota-bound provider
as the default unless the user accepts silent failures.

## Making a fair listening test

Same sentence in every language, rendered once per voice, concatenated with a short silence
and a spoken label per segment (`ffmpeg -f concat`), so the user compares back to back instead
of across three files. Sentence should be accent-loaded: for Spanish, `j/g`, `ll`, `z/ce/ci`,
`rr`, `ñ`, plus question intonation. Duration is a free sanity check — English phonology
stretches Spanish text ~20% longer than a Castilian voice does.

Key distinction to state to the user: "auto-detect" is a property of those models, not a
Hermes feature. Hermes core has zero language logic in the TTS path — grep for `language` in
`tools/tts_tool_providers.py` and the only hit is `tts.xai.language` (default `"en"`).
So `tts.provider: gemini` works, but there is nothing language-related to configure and no
knob if the model picks the wrong variety. Auto-detect answers "which language", never
"which dialect" — for a Spain-based user only an explicit `es-ES-*` voice id guarantees
Peninsular accent. Gemini's `tts.gemini.persona_prompt_file` is a static file re-read each
call, so it can force an accent globally but cannot switch per message — and it only behaves as
direction on the 2.5/3.1 generation; on 3.8 TTS the input is a verbatim transcript (see below).

Edge also ships cross-lingual voices that switch language themselves (verified in the
installed `edge-tts --list-voices`, 322 voices): `en-US-Andrew/Ava/Emma/BrianMultilingualNeural`,
`it-IT-GiuseppeMultilingualNeural`, `de-DE-Florian/SeraphinaMultilingualNeural`,
`fr-FR-Remy/VivienneMultilingualNeural`, `pt-BR-ThalitaMultilingualNeural`, `en-AU-WilliamMultilingualNeural`.
One global voice, no key, no script — but no Peninsular Spanish variant and no per-message
control. There is no `es-*` multilingual voice.

Hybrid worth proposing when the user wants LLM-grade TTS *and* deterministic language: keep
the `type: command` provider but have the script call the vendor API (Gemini) with the
detected language written into the prompt ("Speak Peninsular Spanish, Madrid accent"), so the
model is steered instead of guessing.

## Gemini TTS: choosing the model

Probe, do not reason from the model name — model age, doc headlines and deprecation tables all
disagree. `scripts/probe_gemini_tts_models.py` lists every TTS model the key can see and calls
each with the exact payload Hermes sends, printing status, latency, bytes and returned mimeType.
Full matrix, format handling and the auxiliary-route details: `references/gemini-tts.md`.

Always-on rules that came out of that probe:

- **Hermes reads no mimeType.** `_generate_gemini_tts` wraps whatever bytes come back with
  `_wrap_pcm_as_wav()`. Every model that returns `audio/wav` (all 3.8 TTS) gets double-wrapped:
  22 samples (0.9 ms) of RIFF header decoded as PCM at near full scale, then the audio
  bit-identical. A tick, cosmetic, not fatal. PCM models (2.5 flash, 3.1 preview) are clean.
- **Newer is not automatically incompatible and older is not automatically deprecated.**
  Verify each candidate with the probe before recommending a switch.
- Free tier is per model, not per vendor: `gemini-2.5-pro-preview-tts` answers HTTP 429 with
  `generate_content_free_tier_requests, limit: 0` while its siblings work on the same key.
- Audio-tag rewrite is gated to `gemini-3.1*tts` (see Pitfalls); 3.8 cannot use it through
  Hermes even though it supports richer tagging upstream, because Hermes never sends
  `speech_metadata` and cannot request `audio/l16`.
- On 3.8, `persona_prompt_file` turns into a liability: those models treat the input as a
  verbatim transcript, so prepended direction risks being spoken aloud. Leave it empty there.

Measured on this install, same Spanish sentence: 2.5-flash-preview 4.1 s, 3.1-preview 3.9 s,
3.8-flash-lite 3.0 s, 3.8-flash 2.9 s, Edge 1.2 s. Pricing: 2.5-flash-preview $0.50/1M input
text + $10/1M audio output tokens, free tier *used to improve our products*; 8,192 input /
16,384 output token limits, no streaming below 3.1. Audio bills ~32 output tokens per second,
so nothing plays until the clip is complete. Quote latency only from a probe you ran, never
from a vendor claim.
