---
name: changelog
description: Generate or update CHANGELOG.md in any project by gathering new changes from plan files, git commits, or merged GitHub PRs and rewriting them into a clean, audience-appropriate changelog. Auto-detects existing changelog style (user-facing "What's New" vs. Keep a Changelog) and the best available source. Use whenever the user asks to update the changelog, generate release notes, summarize recent work for users, write a "What's New" or "What shipped this week", or refresh CHANGELOG.md after merges — even if they don't explicitly say "changelog". Do NOT use for ad-hoc commit-message writing, single-PR descriptions, or producing internal standup reports (use `progress-report` or `project-report` instead).
---

# Changelog

Generate or update a `CHANGELOG.md` for any project. Pull new material from whatever source is best available (plan files, git commits, or merged PRs), rewrite it into the style the project already uses, and apply a sensible rolling window so the file stays useful instead of turning into an archive.

## Why this is harder than it looks

Raw commit messages and PR titles read like internal artifacts ("refactor: extract resolver into module", "fix typo in test name"). A changelog is supposed to tell *someone else* — a teammate skimming, a user wondering what changed, a future-you debugging a regression — what actually happened, in their language. The work is the rewrite. The mechanics (where to write, what to skip, how to group by date) are scaffolding around that rewrite.

There are also two genuinely different changelog audiences with different conventions, and conflating them produces a bad file:

- **User-facing / "What's New"** — chronological, benefit-led, plain language, temporal grouping (day → week → month). Good for apps and product surfaces.
- **Keep a Changelog** — version-anchored, technical, sectioned by `Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security`. Good for libraries and CLIs.

This skill detects which the project uses and matches it, rather than imposing one.

## Arguments

The user may pass any of these as natural-language hints; interpret loosely:

- (none) — Incremental update: read metadata, gather only new material since last generation, append.
- `--rebuild` — Regenerate the whole file from scratch, ignoring stored metadata.
- `--dry-run` — Show the would-be content without writing.
- `--source plans|commits|prs` — Override source autodetection.
- `--style user-facing|keep-a-changelog` — Override style autodetection.
- `--since <ref-or-date>` — For commits/prs source, override the "since" anchor (a tag, sha, or `YYYY-MM-DD`).

If the user gives a free-form ask like "update the changelog with everything from the last two weeks", map it to the right flags (`--since 14.days.ago`).

## Phase 0 — Detect mode

Run this before anything else; remember the results for the rest of the workflow.

### Detect style

Read `CHANGELOG.md` (or `CHANGELOG`, `RELEASES.md` — check in that order) if it exists. Decide style by signal, checking in order:

1. **Keep a Changelog** if the file contains `## [Unreleased]`, `## [X.Y.Z]` (semver-tagged headers), or subsection headings like `### Added`, `### Changed`, `### Fixed`. Often opens with a reference to keepachangelog.com.
2. **User-facing temporal** if the file has a `<!-- changelog-meta -->` comment, date headers like `### March 18` or `### Week of March 3`, or bullets that read like benefits (`**Smarter tool discovery** — …`).
3. **Ambiguous existing file** — ask the user once, then proceed.
4. **No existing file** — default to **user-facing** unless this is clearly a library (presence of `package.json` with `version` and a `main`/`module` field plus published-package indicators, a `Cargo.toml`, `pyproject.toml` with `[project]` version, or a `go.mod`), in which case default to **Keep a Changelog**. Confirm the choice with the user when defaulting on a fresh file.

### Detect source

Check what's available, then pick:

1. **Plan files** — `docs/plans/` exists and contains `.md` files
2. **Merged PRs** — `gh` CLI is installed (`gh --version`), `gh auth status` succeeds, and a GitHub remote exists (`git remote -v` shows github.com)
3. **Git commits** — always available in a git repo

**Default preference order:** plans → PRs → commits. Plans are usually the most curated and least noisy; PRs are second-best (one entry per merged feature); raw commits are the fallback.

Tell the user which source you picked and why, briefly: "I'll pull material from merged PRs since the last changelog entry — `docs/plans/` doesn't exist here and `gh` is set up."

If the user passed `--source`, honor it but warn if that source looks empty or unavailable.

## Phase 1 — Read current state

Read the existing changelog (if any). Parse the metadata anchor:

```html
<!-- changelog-meta: {
  "last_generated": "YYYY-MM-DD",
  "style": "user-facing" | "keep-a-changelog",
  "source": "plans" | "prs" | "commits",
  "plans_covered": ["..."],
  "last_commit_sha": "abc1234",
  "last_pr_number": 142
} -->
```

For Keep a Changelog files that don't have this metadata block, derive the "last anchor" from the most recent version header (`## [1.4.2] - 2026-04-18`) — that's the natural boundary.

If `--rebuild`, ignore the metadata and treat everything as new.

## Phase 2 — Gather new material

Use the detected (or user-overridden) source.

### Source: plan files

List all `.md` files in `docs/plans/` recursively. **Filter out:**

- Files already in `plans_covered` (unless `--rebuild`)
- Task-tracking junk: `next-session-prompt.md`, `todo.md`, `lessons.md`, `notes.md`, `scratch.md`
- Implementation/sub-plans: filenames containing `-impl`, `-implementation`, `-tasks`, `-checklist` — these duplicate the design plan they belong to
- Files under `archive/` or `_archive/` subdirectories

For each remaining file, read it. Pull the **Goal**, **Summary**, **Overview**, or **What we're doing** section. If none of those exist, read the first 50 lines and infer.

### Source: merged PRs

```bash
gh pr list --state merged --base <default-branch> --limit 200 \
  --json number,title,body,mergedAt,labels,author
```

Detect default branch with `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.

**Filter out:**

- PRs already covered (number ≤ `last_pr_number`)
- PRs merged before `last_generated` minus a 1-day grace window
- PRs with `chore`, `ci`, `docs-only`, or `dependencies` labels (unless the user said `--include-chores`) — they rarely belong in a user-facing changelog
- Dependabot/renovate PRs (author bots), except security-flagged ones (label contains `security`)

For each PR, work from the title and the first meaningful paragraph of the body — skip template boilerplate ("## Summary", "## Test plan", checkbox lists).

### Source: git commits

```bash
git log <since>..HEAD --no-merges --pretty=format:'%H%x09%aI%x09%s%x09%b%x00'
```

Where `<since>` is:
- `last_commit_sha` from metadata, OR
- Most recent semver tag (`git describe --tags --abbrev=0`) if Keep a Changelog style, OR
- The first commit if `--rebuild` or no anchor exists

**Filter out:**

- Conventional-commit types that don't ship to users: `chore`, `ci`, `build`, `style`, `test`, `refactor` (unless the refactor message says it changes behavior), `docs` (unless the project IS docs)
- Commits matching `^Merge `, `^Revert ` (handle reverts specially — see below)
- Dependency bumps (`bump`, `update.*dep`, `Bump .* from`) unless flagged security

**Handle reverts:** if a commit reverts something already in the changelog, *remove* the reverted entry rather than adding a "reverted" line. If the revert lands too late and the original entry is already in a "frozen" older section, add a one-line note instead.

## Phase 3 — Rewrite into changelog entries

This is the core skill of this skill. Treat it with care.

### Universal rules

- **Lead with the benefit or outcome, not the mechanism.** Bad: `Refactored auth middleware to use JWT with rotating keys.` Good: `Sign-ins survive server restarts; tokens now rotate automatically.`
- **Use the active voice.** "Added X" beats "X was added".
- **Strip internal references.** No ticket IDs, no PR numbers (in the body — they belong in metadata or as links if anywhere), no internal codenames unless they're also the public name.
- **Each bullet is one sentence.** If you need two sentences, the bullet is doing too much — split it.
- **Skip non-events.** Reformatting, lint passes, doc typos, and CI tweaks rarely belong in a changelog. When in doubt, leave it out — sparse is better than padded.

### Style: user-facing "What's New"

Format each bullet as: `- **Short feature name** — Outcome-led sentence in plain language.`

The "feature name" is a 2–5 word noun phrase the user would recognize or that introduces the concept. It's not the file path or the class name.

**Examples:**

| Source material | Changelog bullet |
|---|---|
| `feat: add server-side filtering to inbox query` | `- **Inbox filters** — Filter the inbox without page reloads, including saved combinations.` |
| `refactor: two-layer engine kernel + AHI domain modules` | `- **Smarter tool discovery** — The agent now finds capabilities on demand instead of loading everything upfront.` |
| PR title: "Fix race in webhook retry leading to duplicate deliveries" | `- **No more duplicate webhook deliveries** — Retries now coordinate so events fire exactly once.` |

### Style: Keep a Changelog

For each new entry, assign a category:

| Category | What goes here |
|---|---|
| **Added** | New features, new endpoints, new options |
| **Changed** | Behavior changes that aren't breaking, performance, UX |
| **Deprecated** | Things that still work but will be removed |
| **Removed** | Things that no longer exist |
| **Fixed** | Bug fixes |
| **Security** | CVE fixes, hardening, auth changes — always include even if minor |

Map conventional-commit types when present: `feat` → Added, `fix` → Fixed, `perf` → Changed, `BREAKING CHANGE` → Changed or Removed, `security` (or commits referencing CVEs) → Security.

If the user hasn't tagged a new release version yet, write entries under `## [Unreleased]`. If they have (latest tag matches a new commit cluster), write under `## [X.Y.Z] - YYYY-MM-DD`.

## Phase 4 — Group by time (user-facing style only)

Skip this phase entirely for Keep a Changelog — that style is version-anchored, not time-anchored.

Assign each entry a date:
- Plan source: parse `YYYY-MM-DD` from filename if present, else `git log --diff-filter=A --format=%aI -- <path>` (file creation date)
- PR source: `mergedAt` field
- Commit source: commit author date

Group with tiered detail (configurable defaults below):

| Age | Grouping | Heading |
|---|---|---|
| ≤ 2 weeks | Daily | `### Month DD` (e.g., `### March 18`) |
| 2–8 weeks | Weekly | `### Week of Month DD` (the Monday of that week) |
| 8 weeks – 6 months | Monthly | `## Month YYYY` (condense to 1–3 bullets/month) |

Skip empty days/weeks/months. If a section already exists for a given heading in the current file, **append** new bullets rather than creating a duplicate heading.

## Phase 5 — Rolling window

- ≤ 6 months: keep per Phase 4 grouping
- 6–12 months: condense each month to one line under a single `### Earlier Updates` section at the bottom. Format: `- **Month YYYY** — One-sentence summary of that month's highlights.`
- \> 12 months: remove entirely

For Keep a Changelog: don't apply temporal windowing. Instead, if the file is enormous (>500 entries), suggest splitting older versions into `CHANGELOG.archive.md` — but ask first; don't do it silently.

## Phase 6 — Write & verify

### Update metadata

Refresh the `<!-- changelog-meta -->` comment with:
- `last_generated`: today
- `style`: as detected/chosen
- `source`: as used
- The relevant anchor: `plans_covered`, `last_commit_sha`, or `last_pr_number`

### Write the file

For **user-facing** style:

```
# What's New

<!-- changelog-meta: { ... } -->

### Month DD

- **Feature** — Description.
- **Feature** — Description.

### Week of Month DD

- **Feature** — Description.

---

## Month YYYY

- **Feature** — Description.

### Earlier Updates

- **Month YYYY** — One-line summary.
```

For **Keep a Changelog** style:

```
# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- changelog-meta: { ... } -->

## [Unreleased]

### Added
- Description.

### Fixed
- Description.

## [1.4.2] - 2026-04-18

### Added
- Description.
```

### Verify (light)

After writing:

1. **Markdown sanity check.** Re-read the file. Confirm:
   - Frontmatter / opening heading is intact
   - Metadata comment parses as valid JSON (extract between `<!-- changelog-meta:` and `-->`, run it through a JSON parse)
   - No duplicate top-level headings
   - No empty sections (a heading followed immediately by another heading)
2. **Date sanity.** No entry is dated in the future. No entry is dated before `1900-01-01` (catches parsing bugs).

If `package.json` has a `build` script AND the user passed `--verify-build` (or the file is imported into the app — grep for `CHANGELOG.md` in `src/`), run the build. Otherwise skip — most projects don't import the changelog and running the build is slow.

If any check fails, **don't write** (or revert if already written via `git checkout -- CHANGELOG.md` if it was committed) and tell the user what went wrong.

## Phase 7 — Report

Short, factual summary:

- Source used and what was scanned (e.g., "23 merged PRs since #142")
- New entries added (count, broken down by section if Keep a Changelog)
- Anything condensed or dropped (e.g., "October 2025 month condensed to a one-liner; September 2024 dropped past 12-month window")
- Anything skipped that the user might want to know about (e.g., "Skipped 8 dependabot PRs; one had a `security` label and was kept")

If `--dry-run`, show the full proposed file content instead of writing.

## Edge cases & failure modes

- **Empty source.** If nothing new since last run, say so plainly and exit — don't write an empty section or rewrite the file pointlessly.
- **First-ever run on a project with deep history.** Don't try to summarize 5 years of commits — ask the user where to start (`--since v1.0.0`, `--since 2025-01-01`, or "just this release"). Suggest a reasonable default based on the most recent tag.
- **Style mismatch.** If the user passes `--style keep-a-changelog` but the existing file is user-facing (or vice versa), refuse to silently convert. Surface the conflict and ask: rewrite the whole file in the new style (`--rebuild --style ...`), or stick with the existing style.
- **Multiple potential changelogs.** If both `CHANGELOG.md` and `RELEASES.md` exist, ask which one to update.
- **Monorepo.** If the project is a monorepo (presence of `pnpm-workspace.yaml`, `nx.json`, `lerna.json`, or `workspaces` in `package.json`), ask whether to write a root-level changelog summarizing across packages, or per-package changelogs. Per-package is usually more useful; root-level can become noise.
- **Non-English source.** Don't auto-translate. Match the language of the existing changelog; if creating fresh, match the language of the recent commit messages.
- **Generated-changelog tooling already present.** If `release-please`, `semantic-release`, or a `conventional-changelog` config is detected, surface that and ask whether to defer to it rather than fighting it. Those tools own the changelog in their projects.
