# Choosing and fixing the TTS voice (language / region)

Hermes speaks every reply with **one globally configured voice**. There is no
language detection anywhere in the TTS path: the text's language is irrelevant,
only the configured voice id matters (`hermes_cli/config_defaults.py` `tts.*`).
Consequence: a Spanish/Italian/French reply read by an English voice sounds
"in that language but with an English accent" — the single most common TTS
complaint. The provider is almost never at fault; the voice id is.

## Diagnose before shopping for a new provider

```bash
hermes config get tts.edge.voice        # e.g. en-US-AriaNeural = English voice
hermes config get tts.provider
```

A default install ships `tts.provider: edge` with `en-US-AriaNeural`. If the voice
id's language prefix does not match the language the user speaks, that is the bug.
Do not propose ElevenLabs/OpenAI/Gemini to someone whose problem is a mismatched
voice id — it costs them a signup and money for a one-line fix.

## Fix

```bash
hermes config set tts.edge.voice es-ES-XimenaNeural     # never hand-edit config.yaml
hermes config get tts.edge.voice                        # read back
```

Config changes are picked up by new sessions; in the gateway `/restart`. Verify
end-to-end by calling the `text_to_speech` tool with a short phrase in the target
language and checking the returned file is real audio:

```bash
ffprobe -v error -show_entries format=duration -of csv=p=0 <returned path>
```

You cannot hear the result — so always attach one sample of the chosen voice and,
when the user has a choice to make, a comparison clip of the candidates. Never
claim a voice "sounds natural" without having made the user able to judge.

## Pick the voice id by region, not by "Spanish"

`edge-tts` voices are free, keyless and all neural. Enumerate them (the binary
lives in the PM venv, `which edge-tts`):

```bash
edge-tts --list-voices | grep -E "^es-"      # ^it- , ^en-GB- , etc.
```

Verified `es-*` inventory on this install:

| Voice | Region / gender |
|---|---|
| `es-ES-XimenaNeural` | Spain, female — best default for a Spain-based user |
| `es-ES-ElviraNeural` | Spain, female (older, flatter) |
| `es-ES-AlvaroNeural` | Spain, male |
| `es-MX-DaliaNeural` / `es-MX-JorgeNeural` | Mexico, F / M |
| `es-US-PalomaNeural` / `es-US-AlonsoNeural` | US Spanish, F / M |
| `es-AR-ElenaNeural` / `es-AR-TomasNeural` | Argentina, F / M |
| `es-CO-SalomeNeural` / `es-CO-GonzaloNeural` | Colombia, F / M |
| `es-CL-CatalinaNeural` / `es-CL-LorenzoNeural` | Chile, F / M |
| `es-PE-CamilaNeural` / `es-PE-AlexNeural` | Peru, F / M |

Region beats gender: an `es-MX` voice reading for a user in Madrid still sounds
foreign. Match the user's country (they shop, speak and live somewhere concrete —
use that), then offer 2–3 alternatives rather than a catalogue.

## Comparison clip recipe

Run `scripts/edge_voice_compare.py` (sibling of this reference): it synthesises one
sample per voice, each announcing itself ("Soy Ximena, España, femenina.") before a
neutral sentence, concatenates them with 0.35 s of silence via ffmpeg, and prints
the final mp3 path. Seven voices land at ~65 s — fine to send as one Telegram audio
file. Send the comparison plus one sample of the voice you actually set.

## When the user really wants higher quality than Edge

Say up front that Hermes uses one global voice and ask which one to keep if they
also want English replies.

| Provider | Spanish quality | Cost reality |
|---|---|---|
| Edge (default) | Good neural, slight TTS tell | Free, no key, instant |
| ElevenLabs `eleven_multilingual_v2` | Best; Spanish (Spain) and (Mexico) supported | Free tier 10k credits/mo ≈ 10 min of audio, **no commercial licence**, Voice Library not usable via API on free; Starter $6/mo |
| Gemini `gemini-2.5-flash-preview-tts` | Very good, multilingual voices | Free tier in AI Studio (inputs used for product improvement); needs `GOOGLE_API_KEY`; 32k-char cap. Source: aistudio pricing page |
| OpenAI `gpt-4o-mini-tts` | Very good, steerable via instructions | Paid; needs `VOICE_TOOLS_OPENAI_KEY` |
| xAI | Decent | Paid; `tts.xai.language` accepts BCP-47 or `auto` |
| Piper (`piper`, `es_ES` voices) | Robotic but intelligible | Free, offline; only if offline matters |

Quote live limits as "checked on <vendor pricing page>", not from memory — free
tiers and per-char prices move.

Gemini is not one model but five, they return different audio formats, the free tier is
applied per model (Pro TTS answers 429 `limit: 0` on a free key), and Hermes' adapter
handles only the raw-PCM ones cleanly. Model matrix, the double-WAV-wrap tick and a
re-runnable probe: `references/gemini-tts.md` in the
`multilingual-tts-voice-switching` skill.

## The local `gemini-custom` provider (this install)

- **Knobs** live in `tts.providers.gemini-custom`, re-read on every call (no
  restart, no `/new`). **Single speaker only** — the two-speaker dialogue mode
  and the `~/.hermes/gemini-tts.json` runtime override were removed; the reply
  text is always the transcript, steered by `style` + inline tags. There is no
  per-call override channel left, so a change is `hermes config set` and it
  applies to the next reply.
- **The chunk cap is supplied by the plugin, not by config.** Hermes splits a
  reply before any provider code runs, reading
  `tools.tts_tool_delivery.PROVIDER_MAX_TEXT_LENGTH` (fallback 4000 chars for an
  unknown name). `gemini-custom` publishes its entry at registration time and
  refreshes it from the `pre_llm_call` hook: `inputTokenLimit` x 2 chars/token,
  rounded down to 1000 (8192 tokens → 16000 chars). The introspection
  (`GET /v1beta/models/{model}`) is cached 30 days in
  `~/.hermes/cache/gemini_model_limits.json`, is not a synthesis call, and falls
  back to the documented window when offline. No config key, no "unrecognized
  config key" warning. A flat `tts.<provider>.max_text_length` would still win —
  that is where the chunker looks, and it is a *different* namespace from
  `tts.providers.<provider>`, where the plugin reads its own knobs; Hermes'
  schema only knows built-in provider names, hence the warning.
- **Tags:** `tags: true` inserts `<laugh>`/`<sigh>`/`<breath>` via the auxiliary
  task `tts_audio_tags` (the same helper Hermes' own Gemini/xAI adapters use),
  skipped when the text is already tagged, above 80% of the cap, or when the
  auxiliary call fails (logged; spoken untagged). Off by default: one extra LLM
  round trip per request. Aux caveat on this box: from a bare shell the auxiliary
  client cannot validate the main `opencode-zen` provider and looks for
  `GOOGLE_API_KEY`, while the working key is `GOOGLE_GENERATIVE_AI_API_KEY` — pin
  `auxiliary.tts_audio_tags` to a keyed provider/model if tags must work.
- **Run Hermes-workspace scripts with `python`** (the install venv), not
  `python3`: the `python3` shim re-execs through `runpy` and breaks on stdin or
  heredoc input, and the interpreter it relaunches may lack `ruamel`.
- **Container:** Hermes passes `format` (`tts.output_format`, default mp3) and
  then converts to Opus itself for voice bubbles. The plugin writes `.ogg`
  directly when asked for ogg/opus, which makes Hermes skip that pass —
  `tts.output_format: ogg` is one ffmpeg encode saved per reply.
- **Key names, and a key that exists but is invalid:** the plugin accepts
  `GOOGLE_GENERATIVE_AI_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`. On this box
  a plain shell sees only the first (`GEMINI_API_KEY` is an unresolved `${...}`
  reference), and inside the gateway the same names can be *present yet rejected*
  (`400 API_KEY_INVALID`) — presence is not validity. So consume keys as a
  **candidate list**, retry the next candidate on an auth failure only
  (`api key not valid` / `API_KEY_INVALID`, never on quota or 5xx), and remember
  the key that worked for the rest of the process. Reject values containing `$`
  before trying them.
- Offline suite: `tests/selftest.py` (49 checks, no API calls); contract check:
  `hermes plugins doctor gemini-custom`.

## Pitfalls

- **A dead config key is worse than none.** The plugin shipped `inline_tags`,
  `output_format` and `max_text_length` as knobs that nothing read (and a README
  that promised they worked). When adding a knob, wire it, then prove it with a
  test — a documented-but-inert key costs a debugging session later.

- **Never reach for a new provider before reading `tts.edge.voice`.** Voice-id
  language mismatch is the top cause of "accented" speech.
- **Never edit `config.yaml` by hand** for the voice; `hermes config set` writes it.
- **Don't pick the voice by ear for the user.** You have no audio perception:
  generate samples, attach them, let them choose, then apply the choice.
- **The `text_to_speech` tool has no `voice` argument; the provider's
  `synthesize()` does.** A `/voice` pick and a script's `voice=` argument reach
  the provider as per-call kwargs that beat the config block, but an agent cannot
  pass one through the tool schema — there the configured profile voice is the
  only lever.
- **A single Voice Library / cloned voice on ElevenLabs is not reachable on the
  free plan via API** — cloned or library voices need a paid tier, so don't promise
  a specific community voice on a free key.
