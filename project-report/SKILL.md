---
name: milestone-strategic-standup
description: Create concise, value-centered standup and milestone updates for non-embedded stakeholders. Use when reporting delivery progress, business impact, strategic positioning, and real risks for product, adjacent technical, or executive audiences.
---

# Milestone & Strategic Standup Skill

## Use This Skill When

- The user asks for a standup or milestone report.
- The audience is not embedded in daily implementation.
- The goal is stakeholder clarity on value, momentum, risk, and strategy.

## Inputs

Use the template in `references/input-template.yaml` as the target schema. Gather inputs
from two sources:

### 1. Auto-Gather from Project Artifacts (Internal Research Only)

Before asking the user for anything, read these project sources as **raw research material**.
This data informs the report but must NEVER appear directly in the output.

| Field | Source |
|-------|--------|
| `project_name` | `CLAUDE.md` header or `package.json` name |
| `recent_work_completed` | `git log --oneline -20` on current branch, plus `ROADMAP.md` completed sections |
| `planned_next_work` | Open issues (`gh issue list`), active plan docs in `docs/plans/` |
| `blockers` / `known_risks` | `DEFECTS.md` or `defects/catalog.json` open items |
| `current_milestone` | Active plan docs or ask user |
| `business_objective` | Ask user (or reuse from prior standup if remembered) |

### 2. Ask the User for Remaining Fields

After auto-gathering, present what you found and ask the user to confirm or fill gaps.
Use AskUserQuestion for:

- `audience_type` (product / adjacent_technical / executive)
- `mode` (standup / milestone / default)
- `current_milestone` and `target_date` (if not clear from plans)
- `business_objective` and `strategic_context` (if not previously provided)
- `confidence_level` (on_track / at_risk / ahead)
- Whether to include the optional signal score

### Minimum Required

These fields must be populated (auto-gathered or user-provided) before generating:

- `project_name`
- `current_milestone`
- `recent_work_completed`
- `planned_next_work`
- `business_objective`
- `audience_type`

If key fields are missing after both sources, state unknowns explicitly and limit claims.

## Translation Step (Critical)

The audience is an **external stakeholder** — someone who may understand software or business
generally but has no knowledge of this project's internal tracking systems. Before writing
any output, translate every piece of gathered data:

| Internal language (NEVER use) | External language (USE instead) |
|-------------------------------|----------------------------------|
| Plan numbers (e.g., "Plan 3", "Plan 00") | Describe the **capability** or **goal** (e.g., "table extraction accuracy") |
| Defect IDs (e.g., "DEF-009", "DEF-013") | Describe the **user-facing problem** (e.g., "dense numeric data was being lost during conversion") |
| Issue numbers (e.g., "#12", "issue #5") | Describe what **changed or will change** for the user |
| Milestone names from docs (e.g., "Phase 2b") | Describe the **outcome** (e.g., "multi-page table continuity") |
| File paths or module names | Describe the **functional area** (e.g., "layout analysis", "markdown output") |
| Internal metric names (e.g., "word ratio") | Describe what it **means** (e.g., "content completeness") |
| Commit messages or branch names | Do not reference — describe the result instead |
| ROADMAP.md section titles | Describe the **capability trajectory** in plain terms |

### The Reader Test

Before finalizing output, re-read every sentence and ask:
> "Would someone who has never seen this repo, its issues, its plans, or its roadmap
> understand exactly what this sentence means?"

If the answer is no, rewrite it. Every claim must stand on its own without insider context.

## Modes and Length Policy

- Default (no mode provided): 300-500 words
- `standup`: 150-300 words
- `milestone`: 400-700 words

Mode-specific limits override default.

## Audience Framing Rules

Facts must stay consistent across all audiences. Only framing depth changes.

- `product`: Emphasize user value, roadmap confidence, scope movement, and practical delivery risk.
- `adjacent_technical`: Add pattern-level technical context without implementation detail.
- `executive`: Prioritize strategic leverage, competitive position, risk exposure, and execution health.

## Required Output Structure

Use the exact section order from `references/output-template.md`:

1. Executive Snapshot
2. Functional Progress
3. Milestone Status
4. Strategic Positioning
5. Risks & Tradeoffs

## Strategic Positioning Test

In "Strategic Positioning", explicitly evaluate at least one:

- Cycle time reduction
- Defensibility increase
- Scalability improvement
- Monetization enablement
- Dependency-risk reduction
- Data leverage improvement

If none apply, state exactly:
"This work maintains forward momentum but does not materially change strategic positioning."

## Guardrails

### Never include in output:

- Plan numbers, phase names, or milestone identifiers (e.g., "Plan 3", "Phase 2b")
- Defect IDs or issue numbers (e.g., "DEF-009", "#12")
- File paths, module names, or function names
- Branch names or commit references
- Internal metric names without explanation
- Roadmap section titles or document references
- Any identifier that requires access to the repo to understand

### Do not:

- Overstate impact.
- Inflate minor improvements.
- Turn routine fixes into strategic breakthroughs.
- Use empty phrases like "robust solution" or "cutting-edge."
- Drift into backend-only implementation details.
- Recount work task-by-task.
- Write anything that only makes sense if you've read the project's internal docs.

### Do:

- Describe work in terms of **what the product can now do** that it couldn't before.
- Describe risks in terms of **what could go wrong for the user or business**.
- Separate activity from value.
- Separate output from outcome.
- Separate momentum from strategic advantage.
- Name real risks and concrete mitigation.
- Write so a technically literate person outside the project understands every sentence.

## Output Delivery

Present the report directly in the conversation. If the user asks to save it:

- Save to `docs/reports/` with filename pattern `YYYY-MM-DD_<type>_<audience>.md`
  (e.g., `2026-03-02_standup_executive.md`)
- Do not save automatically — only when explicitly requested.

## Optional Internal Signal Score

Only include if requested:

- Execution Health: Green | Yellow | Red
- Strategic Leverage: Low | Moderate | High
- Delivery Risk: Low | Moderate | High
