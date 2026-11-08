# gemini-custom — Gemini 3.x TTS engine for Hermes

A Hermes TTS provider that talks to the Gemini **`interactions`** speech API
(`POST /v1beta/interactions`), exposing the controls the built-in `gemini`
adapter does not send: `speech_metadata.style`, inline vocal tags, exact audio
encodings and PCM streaming — and it fixes the adapter's double-WAV bug.

One speaker, one turn, the reply text is the transcript. That is the whole job.

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
and converts to the container the caller asked for.

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

Read from `tts.providers.gemini-custom` **on each call**, so an edit applies to
the next spoken reply with no restart and no `/new`. Precedence:
`built-in defaults < this block < per-call voice=/model=/speed=/style=` — the
per-call arguments are how a `/voice` pick and `tools/render.py` flags arrive.

| Key | Default | What it controls |
|---|---|---|
| `model` | `gemini-3.8-flash-tts` | `gemini-3.8-flash-tts`, `gemini-3.8-flash-lite-tts`, `gemini-3.1-flash-tts-preview`, `gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts` (the last needs billing) |
| `voice` | `Kore` | A prebuilt name (`Kore`, `Puck`, …), any id from the Extended Voice Library (`es-ES` castilian voices: `es-es-podcaster-5`, `es-es-training-12`, …), a Voice design `voice_…` id, a replication id, or `auto` |
| `language` | `""` | Only with `voice: auto`: pick the first catalogue voice whose `language_code` matches, e.g. `es-ES` |
| `style` | `""` | `speech_metadata.style` — turn-level delivery: `"whispered urgently"`, `"warm and enthusiastic"`, `"speaking slowly"` |
| `audio_format` | `l16` | `wav`, `l16`, `mulaw`, `alaw` — the encoding requested from the API |
| `sample_rate` | `24000` | `24000`, `16000`, `8000`; the *reported* rate is used for decoding, since the API clamps some encodings (mu-law comes back at 8000) |
| `speed` | `1.0` | Rate multiplier applied locally with ffmpeg `atempo` (the API has no rate parameter); chained for values outside 0.5–2.0 |
| `timeout` | `120` | Seconds per request |
| `retries` | `2` | Retries on 429/5xx, honouring `Retry-After` |
| `voice_catalog_limit` | `0` | Cap on entries returned by `list_voices()` (0 = all 2114); cosmetic, it only trims the picker |

Nothing else: the delivered container comes from the caller's `format`, the
chunk cap from Hermes (below), and vocal tags are simply part of the text.

## Chunk cap — not a plugin setting

Hermes splits a long reply **before** calling the provider and reads the
per-request cap from

```yaml
tts:
  gemini-custom:            # flat tts.<provider> — where the built-ins live too
    max_text_length: 16000
```

That namespace matters: the same key under `tts.providers.gemini-custom` is
never read, and an unrecognised provider silently falls back to 4000 characters.
The plugin cannot supply the number — Hermes resolves it from config before any
provider code runs.

`tools/limits.py` derives a safe value from the model's published window
(`inputTokenLimit` = 8 192 tokens on every 3.8/3.1/2.5 TTS model) instead of a
guess: 16000 chars is ~4 000 tokens of ordinary prose — half the window, with
room for dense text.

## Capability map (Google docs → this provider)

| Gemini capability | How to use it here |
|---|---|
| Single-speaker TTS | one turn: `voice` + optional `style` |
| Turn-level style / pace / tone | `style:` (or `style=` per call) |
| Inline vocal tags (`<laugh>`, `<sigh>`, `<short pause>`) | put them in the text; Hermes' normaliser passes them through untouched |
| Prebuilt voices (30 studio voices) | `voice: Kore`, `Puck`, `Charon`, … |
| Extended Voice Library (2114 voices, 108 Spanish) | `voice: es-es-podcaster-5` etc.; `list_voices()` reads `GET /v1beta/voices`, cached 24 h in `~/.hermes/cache/gemini_voices.json` |
| Voice design / replication ids | `voice: voice_…` (or `voicekey_…`) — passed through verbatim |
| Audio output formats | `audio_format:` + `sample_rate:` pick the encoding; the delivered container follows `format=` |
| Streaming (SSE, raw PCM chunks) | `stream()` yields 24 kHz mono int16 PCM; Hermes' live voice path uses it (`streams_pcm`) |
| Language coverage (130+ languages) | automatic — the model detects the language of the text; `language:` only picks a voice |
| **Two-speaker dialogue** | **not supported.** The API takes exactly two speakers, and a `turns` script replaced the reply text — the provider could never speak what Hermes asked. Removed rather than kept as a trap |

## Runtime behaviour

- Container: Hermes passes `format` (its own `tts.output_format`, default
  `mp3`) and then converts to Opus itself for voice bubbles, because
  `voice_compatible = True`. With `tts.output_format: ogg` the plugin writes the
  `.ogg` path itself and Hermes skips that second encode — one ffmpeg pass
  instead of two.
- Usage log: `~/.hermes/gemini-tts-usage.jsonl` — one line per call with model,
  voice, chars, input/output/audio token counts.
- Failures raise, and Hermes turns them into its error envelope; no silent
  fallback to another engine.

## Limits worth knowing

- **Free tier: 3 requests/minute** on `gemini-3.8-flash-tts`, plus transient
  503 "high demand". `retries` covers the retryable cases; long replies are
  chunked by Hermes and each chunk costs a request.
- `gemini-2.5-pro-preview-tts` returns `429 … limit: 0` on a free key.
- `audio/wav` costs one fewer ffmpeg pass, but `l16` (default) is what keeps the
  pipeline honest about headers; both are byte-identical after conversion.
- Chunking is sentence-aware and happens on the reply text, so a 30 000-character
  reply is two independent requests — and two quota units.

## Helpers

```bash
# render one line (prints the path + a play command), one API request
python3 ~/.hermes/plugins/gemini-custom/tools/render.py "Hola" \
        --voice es-es-podcaster-5 --style warm --format ogg

# browse the voice catalogue (cached 24 h, no API cost)
python3 ~/.hermes/plugins/gemini-custom/tools/voices.py --language es-ES

# what the model's token window implies for tts.gemini-custom.max_text_length
python3 ~/.hermes/plugins/gemini-custom/tools/limits.py

# offline test suite (no API calls)
python3 ~/.hermes/plugins/gemini-custom/tests/selftest.py
```
