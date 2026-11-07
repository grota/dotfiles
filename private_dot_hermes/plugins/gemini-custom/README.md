# gemini-custom — Gemini 3.x TTS engine for Hermes

A Hermes TTS provider that talks to the Gemini **`interactions`** speech API
(`POST /v1beta/interactions`), exposing the controls the built-in `gemini`
adapter does not send: `speech_metadata.style`, speaker turns, inline vocal
tags, exact audio encodings and PCM streaming — and it fixes the adapter's
double-WAV bug.

## Why this exists

The built-in adapter (`tools/tts_tool_providers.py::_generate_gemini_tts`) is
written for the 2.5 generation: it pulls `inlineData.data` out of
`generateContent`, ignores the reported `mimeType`, and prepends its own RIFF
header. Gemini 3.8 already returns a WAV, so the file ends up with a WAV inside
a WAV: 22 samples (0.92 ms) of RIFF header are played as PCM — a click at the
start of every reply — and the rest is shifted by that amount. It also never
sends `speech_metadata`, so on 3.8 (which treats the input as a verbatim
transcript) there is no way to steer delivery.

This provider requests `audio/l16` (headerless raw PCM), wraps it once itself,
and converts to the container Hermes asked for.

## Enable

```bash
hermes plugins enable gemini-custom          # plugin lives in ~/.hermes/plugins/gemini-custom
hermes plugins doctor gemini-custom          # validates the runtime contract
```

Needs `GEMINI_API_KEY` or `GOOGLE_API_KEY` (env or the profile dotenv).

## Select it

```
hermes config set tts.provider gemini-custom
hermes config set --force tts.providers.gemini-custom.model gemini-3.8-flash-tts
hermes config set --force tts.providers.gemini-custom.voice Kore
```

## Every knob

Read from `tts.providers.gemini-custom` **on each call**, so edits apply to the
next spoken reply with no restart. `~/.hermes/gemini-tts.json` overrides it at
runtime (same keys, flat JSON) — handy for one-off changes or for scripting.

| Key | Default | What it controls |
|---|---|---|
| `model` | `gemini-3.8-flash-tts` | `gemini-3.8-flash-tts`, `gemini-3.8-flash-lite-tts`, `gemini-3.1-flash-tts-preview`, `gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts` (the last needs billing) |
| `voice` | `Kore` | A prebuilt name (`Kore`, `Puck`, …), any id from the Extended Voice Library (`es-ES` castilian voices: `es-es-podcaster-5`, `es-es-training-12`, …), a Voice design `voice_…` id, a replication id, or `auto` |
| `language` | `""` | Only with `voice: auto`: pick the first catalogue voice whose `language_code` matches, e.g. `es-ES` |
| `style` | `""` | `speech_metadata.style` — turn-level delivery: `"whispered urgently"`, `"warm and enthusiastic"`, `"speaking slowly"` |
| `speaker` | `""` | Speaker label attached to the single turn (dialogue mode sets its own) |
| `multi_speaker` | `{}` | `{"speakers": [{"speaker": "A", "voice": "Kore"}, {"speaker": "B", "voice": "Puck"}], "turns": [{"speaker": "A", "text": "…", "style": "…"}]}` — exactly two speakers (API constraint) |
| `audio_format` | `l16` | `wav`, `l16`, `mulaw`, `alaw` — the encoding requested from the API |
| `sample_rate` | `24000` | `24000`, `16000`, `8000`; the *reported* rate is used for decoding, since the API clamps some encodings (mu-law comes back at 8000) |
| `output_format` | `""` | Container override; empty = what Hermes asked for (`mp3`, `ogg`/`opus`, `wav`, `flac`) |
| `speed` | `1.0` | Rate multiplier applied locally with ffmpeg `atempo` (the API has no rate parameter); chained for values outside 0.5–2.0 |
| `inline_tags` | `true` | Whether `<laugh>`, `<sigh>`, `<short pause>` style tags in the text are passed through to the model |
| `timeout` | `120` | Seconds per request |
| `retries` | `2` | Retries on 429/5xx, honouring `Retry-After` |
| `max_text_length` | `8000` | Advertised cap; Hermes chunks longer replies |
| `voice_catalog_limit` | `0` | Cap on entries returned by `list_voices()` (0 = all 2114) |

## Capability map (Google docs → this provider)

| Gemini capability | How to use it here |
|---|---|
| Single-speaker TTS | default: one turn, `voice` + optional `style` |
| Turn-level style / pace / tone | `style:` (or per-turn `style` in dialogue mode) |
| Inline vocal tags (`<laugh>`, `<sigh>`, `<short pause>`) | put them in the text; `inline_tags: false` strips them |
| Multi-speaker dialogue (2 speakers) | `multi_speaker.speakers` + `multi_speaker.turns` |
| Prebuilt voices (30 studio voices) | `voice: Kore`, `Puck`, `Charon`, … |
| Extended Voice Library (2114 voices, 108 Spanish) | `voice: es-es-podcaster-5` etc.; `list_voices()` reads `GET /v1beta/voices`, cached 24 h in `~/.hermes/cache/gemini_voices.json` |
| Voice design / replication ids | `voice: voice_…` (or `voicekey_…`) — passed through verbatim |
| Audio output formats | `audio_format:` + `sample_rate:`; `output_format:` for the delivered container |
| Streaming (SSE, raw PCM chunks) | `stream()` yields 24 kHz mono int16 PCM; Hermes' live voice path uses it (`streams_pcm`) |
| Language coverage (130+ languages) | automatic — the model detects the language of the text; `language:` only picks a voice |

## Runtime behaviour

- Voice-bubble delivery: `voice_compatible = True`, so Telegram gets an Opus
  voice note after Hermes' ffmpeg pass.
- Usage log: `~/.hermes/gemini-tts-usage.jsonl` — one line per call with model,
  voice, chars, input/output/audio token counts.
- Failures raise, and Hermes turns them into its error envelope; no silent
  fallback to another engine.

## Limits worth knowing

- **Free tier: 3 requests/minute** on `gemini-3.8-flash-tts`, plus transient
  503 "high demand". `retries` covers the retryable cases; long replies are
  chunked by Hermes and each chunk costs a request.
- **Two speakers max** per request (API constraint, verified).
- `gemini-2.5-pro-preview-tts` returns `429 … limit: 0` on a free key.
- `audio/wav` costs one fewer ffmpeg pass, but `l16` (default) is what keeps the
  pipeline honest about headers; both are byte-identical after conversion.
