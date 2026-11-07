# Gemini TTS through Hermes: models, formats, gotchas

## What the adapter sends

`tools/tts_tool_providers.py::_generate_gemini_tts` POSTs to
`{base_url}/models/{model}:generateContent` with:

```json
{"contents": [{"parts": [{"text": "<prompt>"}]}],
 "generationConfig": {"responseModalities": ["AUDIO"],
                      "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": "Kore"}}}}}
```

Absent on purpose and not configurable: any language field (the model detects it), any
`speech_metadata` annotation (3.8's style/speaker control), any `response_format` /
`mime_type` (so it cannot ask 3.8 for `audio/l16`), and `extra_body` passthrough.
The prompt is `persona_prompt_file` text + transcript glued together by
`_compose_gemini_tts_prompt`, or the bare transcript when no persona file is set.

## Model matrix

Probed with a free AI Studio key against Hermes' own payload; every TTS model the key could
see accepts `generateContent`, so reachability is never the constraint — the returned audio
format is.

| model | result | returned | Hermes handling |
|---|---|---|---|
| `gemini-2.5-flash-preview-tts` | OK, ~4.1 s | `audio/L16;codec=pcm;rate=24000` | clean: wrapped once, correct |
| `gemini-2.5-pro-preview-tts` | HTTP 429, `generate_content_free_tier_requests, limit: 0` | — | needs billing enabled |
| `gemini-3.1-flash-tts-preview` | OK, ~3.9 s | `audio/l16; rate=24000; channels=1` | clean; only model the tag rewrite accepts |
| `gemini-3.8-flash-lite-tts` | OK, ~3.0 s | `audio/wav` (RIFF) | double-wrapped: 0.9 ms tick |
| `gemini-3.8-flash-tts` | OK, ~2.9 s | `audio/wav` (RIFF) | double-wrapped: 0.9 ms tick |

Latencies are per-request wall clock for one short Spanish sentence on a residential link, for
comparison with Edge's ~1.2 s, not as a promise.

## The double-WAV-wrap defect

`_wrap_pcm_as_wav()` (in `tools/tts_tool_delivery.py`) prepends a RIFF header unconditionally,
and the adapter never inspects `inlineData.mimeType`. For a model that already returns a WAV,
the delivered stream is: the inner 44-byte header decoded as 22 PCM samples at near full scale,
then the real audio shifted by exactly those 22 samples and otherwise bit-identical. Google's
own migration note says to drop the manual wrapper for 3.8, so this is a known shape mismatch,
not a bug to hunt.

Measuring it (worth redoing if a future model changes format):

1. Decode the delivered file to raw PCM: `ffmpeg -i out.ogg -f s16le -acodec pcm_s16le -ac 1 -ar 24000 -`.
2. Unpack int16 and compare `samples[:22]` peak against `samples[22:1022]` peak. Header bytes
   read as PCM peak near full scale while speech onset does not.
3. To prove the audio is otherwise intact, compare against a direct render of the *same
   response bytes* through `_wrap_pcm_as_wav` and search the lag over the whole plausible range.
   Search **wide** (thousands of samples) over a window that contains speech: leading silence
   makes every small lag score a perfect 0 difference and yields a false answer.

## Deprecation tables contradict themselves — read both locales

`ai.google.dev/gemini-api/docs/deprecations` lists `gemini-2.5-flash-preview-tts`,
`gemini-2.5-pro-preview-tts` and `gemini-3.1-flash-tts-preview` with a shutdown date, and the
same URL with `?hl=en` says "No shutdown date announced" for the same rows. Do not infer
lifecycle from which model is newer or from one locale's table; quote both and let the user
decide, or check whether the model still answers.

## Auxiliary route behind `tts.gemini.audio_tags`

Tag insertion is a rewrite by the auxiliary task `tts_audio_tags`
(`GEMINI_AUDIO_TAG_REWRITE_TASK`), and it only fires when the TTS model name contains both
`gemini-3.1` and `tts`. Route fields resolve like every other `auxiliary.<task>` block: see the
`hermes-agent` skill's `references/configuration.md`. Any failure — unknown provider, quota,
empty reply — returns the untagged transcript silently, so "tags do nothing" is usually a
routing or model gate, not a prompt problem.

## Reaching 3.8's native controls: write a provider plugin

The adapter above cannot send them, but the API exposes them on a different endpoint.
Verified against the live API, `POST /v1beta/interactions` is the 3.8 path:

- **Single speaker:** `generation_config.speech_config` is a **list** `[{"voice": "Kore"}]`.
  The object form `{"voice": …}` is rejected (`Unknown parameter 'voice'`), as is
  `voice_config` / `voice_name`.
- **Dialogue:** `{"speech_config": {"speakers": [{"speaker": "A", "voice": …}, {"speaker": "B", "voice": …}]}}`
  with exactly two entries — one returns "the number of speaker_voice_configs must equal 2".
  Each turn is its own text part with `annotations: [{"type": "speech_metadata", "speaker": "A",
  "style": "warm and enthusiastic"}]`.
- **Style vs transcript:** `speech_metadata.style` carries turn-level delivery; the text itself
  is a verbatim transcript, so direction written into the text risks being read aloud.
- **Audio format:** `response_format: {"type": "audio", "mime_type": "audio/wav|audio/l16|
  audio/mulaw|audio/alaw", "sample_rate": 24000}`. Unary defaults to WAV with a RIFF header;
  **mu-law comes back at 8 kHz** whatever rate was requested, so decode from the *reported*
  `mime_type` string, never from the request.
- **Response:** audio sits in `steps[*].content[*]` as `{"type": "audio", "data": <b64>,
  "mime_type": …}`; `usage` reports audio output tokens (useful for cost accounting).
- **Streaming:** `"stream": true` returns SSE pairs `event: …` + `data: {…}`; audio chunks are
  `delta: {"type": "audio", "data": <b64>}` as headerless 24 kHz mono int16 PCM.
- **Voice catalogue:** `GET /v1beta/voices` pages 1000 at a time (~2100 on a consumer key, 108
  Spanish, 22 `es-ES`) with
  `{id, type, display_name, language_code, region_code, accent, persona, context, gender, pitch, description}`.
  Those ids are what a `voice:` setting should accept — the only way to guarantee Peninsular
  accent by construction rather than by steering.

Plugin contract, layout, runtime-config pattern and test recipe: `hermes-plugin-development`.
Through the built-in `gemini` provider none of the above is reachable, whatever the config says.
