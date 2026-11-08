---
name: hermes-agent-local
description: "Use for Hermes config, memory, profiles, TTS, dotfiles."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, profiles, memory, tts, auxiliary, local]
    related_skills: [hermes-agent, citation-freshness]
---

# Hermes Agent — local overlay

Local knowledge that the bundled `hermes-agent` hub does not ship. The bundled
skill is upstream-owned (its name is in `~/.hermes/skills/.bundled_manifest`), so
nothing here may be written into it. **Load this skill alongside `hermes-agent`**
whenever the question is about Hermes itself.

## When to Use

Any question about Hermes itself where the bundled `hermes-agent` hub does not
carry the answer: memory layers and retention, profiles and gateways, TTS voice
selection, auxiliary model routing, cron job modes and watchdogs, safe
`config.yaml` edits, and putting the
Hermes home under a dotfile manager. Also load it whenever you load
`hermes-agent`, and before editing anything under `~/.hermes/skills/`.

## Routing

| Question | Read |
|---|---|
| Memory layers, listing/deleting memories, session retention and pruning, "why did it forget", `hermes memory reset`, `/journey` | `references/memory-and-retention.md` |
| A second agent or a household member's own bot: profiles, command aliases, one-gateway multiplexing, channel pairing, `profile_routes`, the shared-bot satellite rule | `references/profiles-and-gateways.md` |
| Per-task auxiliary models (titling, compression, vision, background review, TTS), provider gates, cost caps | `references/auxiliary-tasks.md` |
| Picking or fixing the TTS voice, wrong accent, language binding, comparison clips | `references/tts-voices.md` + `scripts/edge_voice_compare.py` |
| Editing `config.yaml` safely (values via `hermes config set/unset`, stale comments via a data-neutral script, why the "unrecognized key" warning is not a verdict), which changes need a restart vs `/new`, **plugin/provider code always needs a gateway restart** and must be tested in a fresh process, declaring `provides_hooks` so `plugins doctor` stays quiet, keys from the environment instead of `.env`, which env var a provider actually reads (and why the model provider's key must stay in `.env`/the pool), supplying a value the runtime needs *before* dispatch (a plugin publishing into `PROVIDER_MAX_TEXT_LENGTH`) and failing loudly when an internal contract changes, the gateway-service environment, implementing a `secrets.command` helper (and proving no value leaked: `scripts/secret_leak_check.py`) | `references/local-config-and-providers.md` |
| Bundled-skill sync mechanics, `list-modified`/`diff`, the reset traps, salvaging an existing local edit | `references/skills-and-upstream.md` |
| Making a rule enforceable: `pre_tool_call` shell hooks — registering, consent allowlist, blocking contract, `hooks test` | `references/shell-hooks.md` |
| Tracking `~/.hermes` in chezmoi/dotfiles: what to version, encrypted memory files, `forget`/`add --recursive`/`chattr +encrypted` pitfalls | `references/chezmoi-integration.md` |
| Scheduled jobs: which cron mode costs what inference, script-only watchdogs (`--no-agent`), the silent-when-empty stdout contract, proving a fire was actually delivered | `references/cron-jobs.md` |
| Citing hours, prices, schedules or eligibility that may be stale | skill `citation-freshness` |

## Ground rules

- **Never edit a bundled skill.** Local knowledge goes here; upstream-worthy
  fixes are reported to the user. A `pre_tool_call` guardrail enforces this —
  see `references/shell-hooks.md`.
- **A rule the user adopts obsoletes the machinery it replaces.** When a standing
  rule forbids an action outright, delete the recovery tooling for that action
  rather than keeping both (the user will ask for the duplicate to go), and keep
  only the condensed procedure in a reference.
- **Anything that reaches into a Hermes internal must prove itself.** Publish or
  read the internal, then round-trip through the runtime's own resolver and demand
  your value back; on any mismatch fail loudly at registration *and* in the provider
  call, and only log inside hooks. A silent fallback to a default looks like a
  working system and is worse than an error — the procedure is in
  `references/local-config-and-providers.md`.
- **Never read a credential file into the transcript.** Extract names, counts,
  lengths or names-only diffs; when the user asks whether you saw the values,
  state exactly which categories you saw and prove the rest with
  `scripts/secret_leak_check.py` before saying anything about rotation.
- This skill is agent-created: editing it, adding references and patching it are
  all fine, and `hermes update` never touches it.
- Keep the routing row and the reference in sync — a reference nobody routes to is
  dead weight, and a row pointing at a missing file is worse than no row.
