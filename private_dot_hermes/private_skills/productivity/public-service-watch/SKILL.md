---
name: public-service-watch
description: "Watch a public service until it opens to this user."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Monitoring, Cron, Public-Services, Eligibility, Spain]
    category: productivity
    related_skills: [competitor-news-monitor, grounded-citations]
---

# Public-Service Watch

A recurring watchdog for a public-service change the user is waiting on: a
vaccination campaign that has not opened yet, a benefit window, a municipal
service, an administrative deadline. Two things make it different from a news
digest: the user's own eligibility is the filter, and the local facts (his
centre, his district, his town) must be verified once and then frozen into the
job, because each tick runs in an isolated session that cannot ask him anything.

## When to Use

- "Tell me when X opens for people like me" / "when can I do Y".
- "No quiero que sea una tantum, avísame de vez en cuando" — the user explicitly
  asks for a monitor instead of a one-off answer.
- Re-opening or correcting an existing watch after the user says a fact is wrong.

Not for: company/market news (`competitor-news-monitor`), price tracking
(`product-price-monitor`).

## Procedure — Setup (foreground, once)

### 1. Freeze the question, the user's eligibility, and the locality

Write down, before searching: the exact question ("when is flu vaccination open
to healthy adults under 60"), every user attribute that decides eligibility
(age band, risk conditions, who he lives with), and the administrative unit his
answer depends on — municipality **and** pedanía/barrio where it changes which
office serves him.

Resolve garbled place names against the user's known locality before acting
(speech-to-text mangles Spanish toponyms; "chicleana" is Chiclana de la
Frontera). Never ask the user to re-spell a town that is already in memory.

### 2. Verify the local facts against the official registry, not a listicle

For Spanish public services, the authoritative page is the one that enumerates
the unit's own children — e.g. the SAS *Distrito* page lists every zona básica
and every centro de salud inside it, and each centro's ficha gives address,
phones, zone, reference hospital, and an "fecha de actualización". Aggregators,
tourism pages and "N centros de salud en X" listicles routinely omit members.

Emit the count from the distrito page's own list; a single zona básica
routinely holds three or more centros, so a two-item list recalled from the town's
best-known centres is the likeliest error — and the user's own centre is exactly
the one such a list omits.

Done when the count of centres/offices in your note matches the official
enumeration, and every address/phone came from the official ficha. Never infer
assignment from distance — adscripción goes by registered address inside the
zona básica; distance is a sanity check for the user, not the rule.

See `references/andalucia-sas.md` for that site's shape.

### 3. Write the discards into the prompt

The tick sees only the prompt. Every route already ruled out by the user's
situation ("does not live with anyone needing care, so never offer the
cohabitant/carer route") must appear there as an explicit "do not propose this",
or the job will re-suggest it every week.

### 4. Write and create the job

Use `templates/watch-prompt.md`. It must carry: the verified baseline flagged
as *already known, do not report as news*; 1-2 official URLs; a short list of
local-press searches; a focus order for filtering; a one-line "no news" reply;
an escalation format that starts with the actionable phrase ("YA PUEDES
VACUNARTE") plus the exact procedure; and an instruction for when the window
closes (pause until next season).

Create with `continuity=true` (so each run sees its own previous output and can
dedupe), `deliver="origin"`, `enabled_toolsets=["web"]`, and the user's
timezone.

### 5. Correct it in the same turn the user corrects you

When the user says a frozen fact is wrong, patch the job prompt **in the same
reply** as the corrected answer. A fix that lands only in chat is undone at the
next tick — the job keeps mailing the old fact.

Update with `cronjob_manage(action="update", job_id=…, prompt=<whole new
prompt>)`: the prompt is replaced wholesale, not merged, so keep the parts that
were already right. Then confirm persistence by reading
`~/.hermes/cron/jobs.json` — job objects key on `"id"`, while the tool reports
`job_id`; grep for the id and check the markers you just added are present.

That read is verification only. Never save a prompt by editing `jobs.json`
directly: the scheduler holds the job in memory and rewrites the file wholesale,
so a hand edit is silently reverted on the next tick or any other job change.

## Procedure — Tick (each scheduled run)

1. Official page(s) first: eligibility groups, opening dates, end of campaign.
2. If a walk-in/no-appointment service exists, read the official list of points
   and check whether the user's own centre is on it, with its current hours.
3. 1-2 local searches for the last 14 days, scoped to region → province →
   municipality/pedanía.
4. Compare with the frozen baseline and with the previous run's output. No real
   change → one line, with the date checked. Change → 3-6 lines: what changed,
   since when, where exactly he goes, source URL.

## Pitfalls

- **A schedule list can be from last year's campaign and look current.** The
  venue name never changes, so "Centro de Salud X, 16:00-19:00" reads as today's
  until you check the article's publication date and which campaign it describes.
  Same trap with a Junta press release naming the centre: check its year before
  quoting it. Quote a schedule only from the current campaign's official list.
- **A service badge on one centre's ficha is not evidence for another.**
  Presence/absence of a "sin cita" link differs per centre page and may be
  template noise; treat it as unknown until the official points list confirms.
- **Name-first verification passes on the wrong entity.** Two centres with
  similar names ("Los Gallos" as a barrio, a closed consultorio, and the current
  centro de salud) all surface for the same query — pin the address and the
  ficha's update date.
- **"Sin cita" is a channel, not an eligibility change.** Walk-in days serve the
  campaign's target groups. Press headlines drop that qualifier ("los andaluces
  podrán vacunarse sin cita") — which is exactly why the user forwards them
  expecting good news. Read the body paragraph, which usually still says "para
  los grupos diana", and answer the eligibility question and the schedule
  question separately.
- **A forwarded item whose headline and body disagree is unresolved, not news.**
  Same-day coverage of one press release can carry two start dates (headline
  rescheduled, body still the original) while the official page carries a third.
  Check the official page, then say which date you are following and why. A
  rescheduled first walk-in day is a schedule change, never an opening.
- **Name a campaign by both of its years, beside the publication date.** "Los
  horarios de 2026" reads as current to a user living in 2026 even when you meant
  the 2025-26 campaign that ran into March 2026. Write "campaña pasada,
  publicada en noviembre de 2025" in the chat and in the prompt alike.
- **Don't let the job drift into general news.** The user asked for one question
  answered; national comparisons and other regions are filler unless they change
  his answer. Filter region → province → municipality, and say what you filtered.
- **Don't let a ruled-out route creep back in** on the next tick because it was
  only excluded in conversation (step 3).
- **Don't answer the local question from memory of a previous campaign.** The
  frozen baseline must come from the official page of the campaign in question.

## Verification

- [ ] Every frozen local fact traces to an official page (URL + update date).
- [ ] The centre list matches the official enumeration, not a listicle.
- [ ] Discarded routes and the user's eligibility attributes are in the prompt.
- [ ] Hours/eligibility quoted for the current campaign only.
- [ ] Nothing asserted from a headline alone; eligibility and schedule answered separately.
- [ ] `~/.hermes/cron/jobs.json` shows the new prompt with your markers present.

## Reference

- `references/andalucia-sas.md` — how the SAS/Junta site is organised, which page
  enumerates centres, and where the walk-in points list lives.
- `templates/watch-prompt.md` — prompt skeleton for a new watch job.
