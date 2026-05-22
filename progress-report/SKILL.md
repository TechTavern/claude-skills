---
name: progress-report
description: Generate project-level progress reports (standup, milestone, executive summary) for non-technical PMs and managers. Accessible language, capability-focused, ties work to strategic positioning where available.
allowed-tools: Bash(git log:*), Bash(git show:*), Bash(git diff:*), Bash(git status:*), Bash(ls *), Bash(cat *), Bash(find *), Bash(test *)
---

# /progress-report — Project-Level Report Generator

## Purpose

Generate progress reports, standup updates, and executive summaries for non-technical readers (product managers, engineering managers, business stakeholders). Reports must be:

- **Accessible** — plain English, no jargon, no code references, no internal acronyms
- **Accurate** — every claim traceable to a commit, plan file, or changelog entry
- **Capability-focused** — what the product can now do, not how it was built
- **User-anchored** — every capability framed in terms of what an end user gets out of it
- **Strategically positioned** — where strategy material exists, tie the work back to the product's market position

## Arguments

- `standup` — Short report for the last 1–3 business days. What got done, what's next, blockers. Default audience: `mixed`.
- `milestone` — Report on a specific initiative reaching a phase boundary. Pass the milestone name as the next argument.
- `executive` — Period summary (default last 7 days) with stronger strategic positioning and explicit risk catalog. Default audience: `executive`.

**Modifier flags:**
- `--audience=<executive|product|engineering|mixed|adjacent-technical>` — adjusts depth and vocabulary
- `--since=YYYY-MM-DD` — explicit period start (default: last 1 business day for standup, last 7 days for executive, since last milestone report for milestone)
- `--days=N` — alternative to `--since`
- `--output=<path>` — explicit output path (default auto-resolved, see Step 1)
- `--dry-run` — show the report content without writing the file

## Audience tuning

| Audience | What changes |
|---|---|
| `executive` | Highest altitude. Strategic positioning weighted heavily. Risks explicit and unvarnished. No implementation detail. ~600–900 words. |
| `product` | Capability- and user-benefit focused. Light strategic framing. Roadmap implications named. ~600–800 words. |
| `engineering` | Slightly more implementation context allowed (still no code). Architecture decisions and tradeoffs named. Internal risks surfaced. ~700–1000 words. |
| `mixed` | Default for standups. Balances capability detail with enough context for engineering-adjacent readers. ~500–800 words. |
| `adjacent-technical` | For peers in other teams who know the domain but not this codebase. Slightly more vocabulary latitude, still outcome-led. ~600–900 words. |

## Steps

### 1. Discover project context

Detect the project's conventions before composing. Check in this order and remember what you find:

1. **Reports directory** — first match wins:
   - `docs/reports/` (preferred)
   - `reports/`
   - `docs/standups/`
   - If none exists, ask the user where to put the report (offer `docs/reports/` as the default to create).

2. **Plans directory** — first match wins:
   - `docs/plans/`
   - `plans/`
   - `docs/roadmap/`
   - Optional. If none exists, work entirely from `git log` and the changelog.

3. **Changelog** — at repo root:
   - `CHANGELOG.md` (preferred — already in user-facing language; reuse phrasings)
   - `CHANGES.md`, `HISTORY.md`
   - Optional. If present, use it as a primary phrasing source.

4. **Strategy / positioning material** — for the Strategic Positioning section:
   - `docs/strategy/`
   - `docs/positioning/`
   - `STRATEGY.md`, `POSITIONING.md`
   - Optional but heavily used when present. If none exists, the Strategic Positioning section is shorter and asks the user inline about positioning for unfamiliar work.

5. **Prior reports** — read at least one matching exemplar in the reports directory to calibrate tone, length, and section structure. If no prior reports exist, use the structure templates in Step 4.

6. **Active branch + default branch:**
   - Default branch is typically `main`. Project-specific branches like `develop`, `deploy`, `staging` are common.
   - Run `git remote show origin | grep "HEAD branch"` to confirm.
   - "Shipped to production" usually means landed on the default branch. "Shipped to staging" usually means landed on `develop` (if it exists) or a staging branch.

### 2. Determine type, audience, and period

Parse args. Validate the audience flag. If `milestone` is requested, prompt for the milestone name if not given. Resolve the date window:

- `standup`: last 1–3 business days (skip weekends; if today is Monday, cover Thu–Fri prior)
- `executive`: last 7 days (or `--days`/`--since` if provided)
- `milestone`: since the prior milestone's report on the same topic, or 14 days back if no prior

### 3. Gather raw material

Read in parallel:

- `git log --no-merges --pretty=format:'%h %ad %s' --date=short --since=<window-start>` — commits in window
- `git log --merges --pretty=format:'%h %ad %s' --date=short --since=<window-start>` — merge commits (PR landings)
- The changelog (if found) — already-translated user-facing language; reuse phrasings when applicable
- Roadmap / plan files updated in the window (`git log --since=<window-start> -- <plans-dir>`)
- The active tracker files in the plans directory (look for files named `*tracker*`, `*roadmap*`, or with `status:` frontmatter)
- The most recent prior report of the same type — for tone calibration and to avoid restating already-covered material
- Strategy material (if found) — read the top-level strategy doc plus any positioning-specific docs

### 4. Frame each completed body of work three ways

For every item that will appear in the report, produce three framings in your head before writing:

1. **Capability** — One sentence: "The product can now ___ (that it couldn't before)." If the answer is "nothing user-visible," the item is groundwork — frame it as foundation for a named upcoming capability instead.
2. **User benefit** — One sentence: "This matters to a user because ___." If you can't write this without straining, the item probably isn't ready for an executive-audience report.
3. **Strategic positioning** — One sentence: "This strengthens the product's position by ___" where ___ ties to a positioning lever drawn from the project's strategy material (see Step 1.4). If no strategy material exists, or the item doesn't credibly map to a lever, say so honestly — not everything is strategic. Don't force a positioning frame.

### 5. Compose the report

Use the section structure below, matched to type. Match the project's existing report style if prior reports exist; otherwise use these templates.

**Standup structure:**

```
# <Project> — <Audience-Tagged> Standup (<DateRange>)

## Executive Snapshot
<2–4 sentences. What landed, the headline capability, posture.>

## Functional Progress
<2–5 paragraphs, one per major body of work. Lead each with a bold capability label.>

## Milestone Status
<For each in-flight milestone touched in window: one paragraph + confidence label (On track / At risk / Blocked).>

## Risks & Tradeoffs
<Bullet list, 2–4 items, plain language.>
```

**Milestone structure:**

```
# <Project> <Milestone Name> — Milestone Update (<Date>)

## Executive Snapshot
<2–4 sentences naming the milestone, what landed, and whether the milestone is now complete / next phase begins.>

## What Changed
<3–6 paragraphs, capability-led.>

## What Users See
<Concrete user-visible behaviour, before vs after.>

## Strategic Positioning
<2–3 paragraphs explicitly tying the milestone to positioning levers from the project's strategy material. Skip or shorten if no strategy material exists.>

## Remaining Work
<What's next in the initiative. Confidence labels.>

## Risks & Tradeoffs
```

**Executive structure:**

```
# <Project> Milestone Update — <Date>

**Audience:** Executive
**Period covered:** <DateRange>
**Reporting day:** <Date>

## Executive Snapshot
<3–5 sentences. Lead with the headline, name 2–3 capabilities, posture statement.>

## Functional Progress
<Capability-focused paragraphs. Cap of 4 major themes. Bold the capability, then the user benefit, then any context.>

## Milestone Status
<Every in-flight initiative gets a paragraph + confidence label.>

## Strategic Positioning
<2–4 paragraphs explicitly mapping the period's work to positioning levers. Shorter section or omitted if no strategy material exists.>

## Risks & Tradeoffs
<Bullet list of real risks, named honestly. No hedging.>
```

### 6. Voice and language rules

Strict. Apply to every sentence:

- **No code references.** No file paths, no function names, no class names, no PR numbers in the body. PR numbers can appear in an optional footnotes section at the end, never inline.
- **No internal acronyms** without expansion. If you must mention them, expand and explain in the same sentence, or rewrite to avoid.
- **No marketing voice or hype.** "Massive improvements," "game-changing," "groundbreaking," "revolutionary" — banned. State what changed and let the impact speak.
- **Don't pad.** Every sentence earns its place. If a paragraph could be cut without losing information, cut it.
- **Active voice, past tense for what shipped, present tense for current state.** "The agent now does X." "We shipped Y." Avoid "we have implemented" — use "we shipped" or "the product now."
- **Numbers anchor claims.** When you say "faster" or "more reliable," say how much — pull from the changelog or commit messages. If no number, drop the comparative claim.
- **"Confidence" labels are honest.** Only one of {On track, At risk, Blocked}. Don't invent intermediate labels. If it's at risk, say what the risk is in one clause.
- **Lead each capability paragraph with a bolded label**, then a colon, then the explanation. Match the project's prior-report style when prior reports exist.

### 7. Accuracy rules

- **Every functional-progress claim must trace to a commit, plan file, or changelog entry in the window.** If you can't trace it, omit it.
- **Distinguish branches.** "Shipped to staging" vs "shipped to production" matters. Look at which branch the commits landed on (default branch = production by default; the project's staging branch, often `develop`, = staging).
- **Don't claim a milestone is complete unless it actually is.** Cross-reference the tracker file. If a tracker says "in progress," the milestone isn't done.
- **Surface blockers honestly.** If something is blocked on an external team or decision, name the dependency. Don't hide it under "on track."
- **When uncertain, ask the user before writing.** Better one clarifying question than a confidently wrong claim. Especially: positioning framing for unfamiliar work, milestone-completeness judgements, and audience-appropriate vocabulary.

### 8. Write the file

Default path: `<reports-dir>/YYYY-MM-DD_<type>_<audience>.md` (e.g., `docs/reports/2026-05-20_standup_mixed.md`).

If `--output` was provided, use that path. If the auto-resolved path already exists for today, suffix with `-2`, `-3`, etc.

Write the report. Show the user the resolved path and offer a one-paragraph summary of what was generated.

If `--dry-run`, print the content to stdout instead of writing.

## Strategic positioning — how to use it well

Strategic positioning is the section where a report says *why this work matters for the product's market position*, not just what it does. Used well, this is the section that earns the report a second read from an executive. Used badly, it sounds like marketing.

**How to do it well:**

1. **Find the project's positioning material.** Read what's in `docs/strategy/`, `docs/positioning/`, or equivalent. Note the strategic levers the project's leadership actually uses — usually 3–6 named themes (e.g., "ground-truth extraction over guesswork," "governance + AI convergence," "industry-standard alignment"). These are the legitimate frames.

2. **Map work to existing levers, not invented ones.** If a piece of work strengthens "ground-truth extraction," say that. If it doesn't credibly map to any documented lever, do not invent a new lever to fit — either drop the strategic frame for that item, or ask the user how to frame it.

3. **Concrete > abstract.** "Closes the most reputationally dangerous failure mode an AI assistant can exhibit" beats "improves trustworthiness." The verbatim concrete framing is harder to write and much more credible.

4. **Honesty about non-strategic work.** Bug fixes, dependency bumps, and routine maintenance often don't have a strategic frame. That's fine. Group them into a "reliability + maintenance" paragraph and don't try to dress them up.

5. **One lever per item, not three.** If a piece of work touches multiple strategic themes, pick the strongest one. Listing three diluted frames is worse than naming one strong one.

**If no strategy material exists in the project:**

- The Strategic Positioning section becomes a "Why this matters" section
- Frame work in terms of user impact, competitive comparison, or operational risk reduction — whichever the user can validate
- Ask the user before publishing the report whether the framing is right

## Reference: what good looks like

Before composing a new report in an unfamiliar project, read at least one prior report from that project's reports directory. Match its structure, altitude, and tone. If the project has no prior reports, the templates in Step 5 are the starting point.

Good reports share these properties:

- A reader who hasn't followed the work in detail still understands what shipped and why it matters by the end of the Executive Snapshot
- Every functional progress claim is concrete enough that the reader can imagine the before/after
- The Strategic Positioning section names *which* lever, not just *that* positioning improved
- Risks & Tradeoffs surface things the reader didn't already know — if every risk listed was obvious, the section isn't doing its job
- The report is the shortest it can be while still being complete
