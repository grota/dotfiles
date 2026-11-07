---
name: verifying-external-service-access
description: "Verify an external API serves you before committing config."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [api, verification, configuration, providers, entitlements, probing]
    related_skills: [hermes-agent, systematic-debugging]
---

# Verifying External Service Access

## When to Use

Use before committing a config change that points Hermes (or any tool) at a
remote model, TTS/STT provider, API key, MCP server, or backend the user named
but has never run successfully from this machine.

Also use when the user reports a capability "isn't free", "doesn't work", or
"isn't available" and the claim is about someone else's service — the cheapest
way to settle it is one live probe, not an argument from docs.

**Don't use for:** a change you can fully verify locally (a file edit, a CLI
flag), or a service you have already probed successfully this session.

## The rule that matters

**Probe first, commit second, revert third.** An advertised model is not a
usable model. `/models` lists what the provider sells; only a real completion
call proves *this* account, *this* region, *this* client path may use it.

Writing the config value before probing leaves the user on a broken default if
the probe fails. Set → probe → keep or revert, in that order.

## Standing rules

- **Never leave an unproven value as the live default.** If the probe fails,
  restore the previous value and say plainly what failed and why. A user who
  discovers their agent is erroring on every turn because you optimistically
  wrote a config line is worse off than if you had never touched it.
- **A listing is not an entitlement.** `GET /models` returning an ID proves the
  name is spelled right. It proves nothing about whether a completion on that
  ID succeeds.
- **Probe with a minimal real completion**, not a HEAD/OPTIONS/existence check.
  A 6-token prompt with a short timeout answers the only question that matters.
- **Send an explicit `User-Agent` on every probe request.** Provider edges
  commonly 403 a default `urllib`/`Python-urllib` agent while accepting a
  curl-like one. A 403 on `/models` from a bare urllib call is an agent filter,
  not a broken key — re-probe with a UA header before drawing any conclusion.
- **Read the error body, not just the status code.** These failures all return
  HTTP 200-with-error or 4xx with a one-line `message` that names the actual
  cause. The status code alone cannot distinguish them.
- **A single model refusing while its siblings serve is a model-level answer, not
  a route-level one.** Batch-probe the neighbouring models before concluding
  anything about your client path, credentials, or region — and say so explicitly
  when the answer is per-model.
- **Distinguish failure classes before advising.** "Geo-blocked", "client-gated",
  and "bad key" have opposite remedies — see the taxonomy below. Never collapse
  them into "it doesn't work".

## Failure taxonomy

| Message shape | Class | What it means | Remedy |
|---|---|---|---|
| `not available in your country` / `not available in your region` | geo-block | The vendor will not serve this model to this user at all | No local fix. Pick a different model or a different vendor. |
| `can only be used from within <App>` | client-gate | Vendor restricts the free tier to its own client | **Not a verdict yet** — this message is overloaded. Run the control probe below to split "wrong client path" from "this model is not entitled". |
| 401 / `invalid_api_key` | auth | Key missing, wrong, or wrong scope for this endpoint | Fix the key or its permissions. |
| 404 / `model_not_found` | naming | The ID is misspelled, renamed, or not in this account's tier | Get the ID from the provider's own listing. |
| 429 / 5xx / timeout | transient | Not a verdict yet | Retry with backoff before concluding anything. |

Geo-block and client-gate are *provider policy*, not local breakage. Reporting
either as "the tool is broken" sends the user debugging a system that is working
exactly as designed.

## The control probe for "can only be used from within <App>"

This message has three distinct causes with three different remedies, and the
wording is identical for all of them:

1. Your request genuinely lacks the vendor's client credentials/signature.
2. Your provider *name* in config names something that doesn't exist, so the
   tool is quietly taking a fallback path instead of the integration you meant.
3. The model itself is not entitled on your account — everything else is fine.

Run the **sanctioned client for the credential path** against the same model as
a control. "Sanctioned" means whichever client owns the auth envelope that
vendor accepts — NOT automatically the vendor's own official CLI.

A vendor's official CLI typically authenticates with a real account key or an
app-level token. A plugin/adapter that fronts the same endpoint may instead send
a keyless placeholder bearer, a vendor-specific session header, and a pinned
User-Agent. Those are *different envelopes*, and the vendor gates on the envelope.
So: reproduce the refusal inside the vendor's official CLI while your config
routes through a plugin, and the CLI's failure proves nothing about your path —
it is testing credentials your path never uses. Probe the model through the
**provider you are actually configured on** before believing any refusal.

The control is only decisive when the control client and the configured path
share one envelope:

- Sanctioned client completes it → your config path is wrong; fix the config.
- Sanctioned client returns the identical refusal → cause 3, model-level
  entitlement; provider surgery cannot help.

Escalate to this probe only after checking the config name and its owning plugin
first — otherwise you are debugging the vendor for a typo in your own file.

## Procedure

1. **Check whether a plugin provides this provider before concluding it does
   not exist.** `hermes plugins list` first: model-provider plugins register
   names (`opencode-free`) that core no longer ships, and disabling or
   "correcting" such a name breaks a working setup. A core-only grep for the
   name is not evidence it is phantom. If a plugin owns it, probe through that
   provider — never hand-roll a request, because a plugin sends its own auth
   envelope and the vendor refuses anything else. Reject a vendor 403 only when
   the provider you are configured on produced it.
2. **Read the current config** for the value you intend to change, so you know
   the exact previous value to restore. Do this before writing anything, and
   copy the file aside — one command now is the difference between "I reverted
   it" and "please restore your config". Diff against that copy when you restore
   instead of retyping values from memory.
3. **Get the authoritative identifier list** from the provider itself (usually
   `GET /models` with the user's existing key) rather than from memory, docs,
   or a guessed spelling. Model and product names drift; the endpoint is truth.
4. **Probe each candidate with a minimal completion** — sequential or low
   concurrency, short per-request timeout, explicit `User-Agent`. Record
   latency and the exact error string for every candidate, including failures.
   `scripts/probe_models.py` does this and prints a classified report.
5. **Only then write the config**, choosing a candidate that actually returned
   a completion. Use the proper config command (`hermes config set ...`), never
   a hand edit.
6. **Revert immediately on failure** and report the taxonomy class per
   candidate. If nothing passed, say so and leave the original default in
   place.
7. **Tell the user what the constraint actually is**, with the vendor's own
   wording quoted, plus at least one concrete alternative path.

## Pitfalls

- **A user dictating an identifier by voice will garble it.** Transcribed model
  and product names are frequently mangled ("Fledged Alpha Free" for
  `fledge-alpha-free`). Never act on the transcribed spelling — resolve it
  against the provider's listing and confirm the match before switching.
- **Don't present an untested list of alternatives as usable.** Batch-probe
  them first and report which respond; a menu of plausible-sounding IDs that
  all error wastes a round trip and trains the user to distrust the report.
- **Correct the record in the same reply, without padding.** When your own
  probe or config edit was wrong, say which claim was wrong, why the method
  was wrong, and what the verified result is. No restating the earlier report,
  no apology scaffolding. The user is auditing precision — lead with the
  corrected fact.
- **A fast failure is not a working model, and a slow one is not a broken
  one.** Judge by whether a completion came back, not by latency.
- **One model working does not mean the provider is healthy for the tier.**
  Test the specific candidates the user asked about.
- **Probe with the key the user actually configured**, loaded from their env
  file — not a key you invent. A probe under different credentials answers a
  different question than the one the user asked.
- **A config key holding a provider name that no longer exists is the cheapest
  bug to miss and the most expensive to chase.** It does not fail loudly at the
  place you changed it; it degrades into a generic fallback and the symptom
  surfaces later as a vendor-side error message that points in exactly the wrong
  direction. Verify the name resolves before you start interpreting vendor
  responses.
- **When the user tells you this error has happened before, believe them before
  forming your own theory.** A prior occurrence of the identical message is
  strong evidence of a recurring local cause. Reproduce the earlier
  configuration and diff it against the current one before writing any new
  explanation — a confident wrong theory costs more than one extra probe.
- **Don't trust a config change to take effect mid-session.** Provider routing is
  often resolved per turn or per process; tell the user which action actually
  picks up the new value (fresh session, restart) instead of implying the edit
  is already live everywhere.
- **Permanently retire a name that no longer resolves** with the tool's
  per-provider disable flag, in the same pass as repointing the config. A
  disabled phantom name fails fast and loudly; a live one keeps silently
  degrading into a fallback. **The flag matches the requested string literally,
  not the resolved provider, so one alias family needs one key per spelling** —
  disabling the canonical name leaves its aliases working, and a user who
  re-requests one lands back on the route you just retired. Enumerate every
  alias (`hermes` exposes them in the provider registry), write a key for each,
  then re-probe each spelling to confirm it now fails. See
  `references/hermes-provider-config-and-caches.md`.
- **Never write a config field whose value the provider or plugin already
  defaults.** An endpoint URL the plugin hardcodes, a retry count, a timeout —
  writing it into user config converts a working default into an override that
  silently outlives the default it replaced. Only set a field you have a reason
  to pin, and unset any you set only while testing.
- **When restoring a config, diff against the backup you took — do not retype
  it.** Reconstruction from memory reintroduces your own test edits as if they
  were the user's settings, and you will not notice.

## Verification

- [ ] Previous config value captured before any write
- [ ] Provider/credential name confirmed to resolve, not just to be spelled
- [ ] Candidate IDs came from the provider's own listing, not transcription
- [ ] Every candidate probed with a real completion, failures included
- [ ] Each failure classified (geo-block / client-gate / auth / naming / transient)
- [ ] Config written only to a candidate that returned a completion
- [ ] No field pinned that the provider/plugin already defaults; test-only edits unset
- [ ] Retired provider names disabled under EVERY alias spelling, each re-probed
- [ ] On total failure: previous value restored and reported, not left broken
- [ ] User told the vendor's constraint in their terms, plus an alternative path
