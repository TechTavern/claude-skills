---
name: dependency-upgrade
description: Audit, research, plan, and execute staged JavaScript/TypeScript dependency upgrades for any npm or pnpm project, with Snyk security checks and build/test/lint gates between groups. Use whenever the user asks to update dependencies, bump packages, upgrade libraries, refresh the lockfile, deal with outdated deps, or do a "dependency cleanup" — even if they don't say "staged" or mention Snyk. Auto-detects package manager from the lockfile and adapts commands accordingly. Do NOT use for single ad-hoc installs ("add lodash") or for non-JS ecosystems.
---

# Dependency Upgrade

Perform informed, staged dependency upgrades on any npm or pnpm project. Audit with Snyk, research breaking changes, group by relationship and risk, execute with verification gates between groups.

## Why staged upgrades

A single `npm update` across dozens of packages produces a non-bisectable mess if anything breaks. Grouping by ecosystem (e.g., react + react-dom + @types/react together) keeps peer-coupled packages aligned, and gating each group on build/test/lint makes failures attributable to a specific change. The Snyk pass adds a security lens that pure version-bumping ignores — sometimes a "minor" bump exists primarily to patch a CVE, and the user should know that's what they're getting.

## Phase 0 — Detect the project

Run these once at the start and remember the results for the rest of the session:

1. **Package manager.** Check the project root:
   - `pnpm-lock.yaml` exists → **pnpm**
   - `package-lock.json` exists → **npm**
   - Both → ask the user which is canonical; if they don't know, prefer the one most recently modified
   - Neither → stop and tell the user: "No npm or pnpm lockfile found. Run `npm install` or `pnpm install` first, or confirm this project uses a supported package manager."

2. **Available scripts.** Read `package.json` and note which of `build`, `test`, `lint`, `typecheck` exist under `scripts`. You'll only run gates for scripts that exist. If `test` is missing entirely, warn the user there's no test safety net — but proceed.

3. **Command map** (use throughout the workflow based on detected PM):

   | Action | pnpm | npm |
   |---|---|---|
   | List outdated (JSON) | `pnpm outdated --json` | `npm outdated --json` |
   | Add prod dep | `pnpm add <pkg>@^<ver>` | `npm install <pkg>@^<ver>` |
   | Add dev dep | `pnpm add -D <pkg>@^<ver>` | `npm install --save-dev <pkg>@^<ver>` |
   | Install (refresh lockfile) | `pnpm install` | `npm install` |
   | Run script | `pnpm <script>` | `npm run <script>` (use `npm test` for `test`) |
   | Lockfile name | `pnpm-lock.yaml` | `package-lock.json` |

   Note: `npm outdated` exits non-zero when packages are outdated, which is normal — don't treat that exit code as a failure.

## Prerequisites

1. **Snyk authentication.** Run `snyk whoami 2>&1`. If not authenticated, stop and tell the user:
   > Snyk requires a free account. Run `snyk auth` to authenticate via browser, or set `SNYK_TOKEN` as an environment variable. Free tier has a monthly test limit.

   Do not proceed until authentication is confirmed.

2. **Baseline project health.** Run each available script in sequence and confirm it passes:
   - `<pm> build` (if `build` script exists)
   - `<pm> test` (if `test` script exists)
   - `<pm> lint` (if `lint` script exists)
   - `<pm> typecheck` (if `typecheck` script exists)

   If anything fails, report the failures and **stop**. The project must be in a passing state before upgrades, otherwise you can't attribute later failures to the bumps.

   If `<pm> test` passes but reports zero test files, warn the user — silent test passes are nearly as bad as no tests.

3. **Working tree.** Run `git status`. If there are uncommitted changes to `package.json`, the lockfile, or other tracked files, stop and ask the user to stash or commit them first. The workflow relies on `git checkout --` for rollback, which would discard their work.

## Phase 1 — Discovery

1. Run `<pm> outdated --json`. Parse the output to get current and target versions for every outdated package.

2. **Classify each bump** by comparing semver: current vs. latest.
   - `patch` — only the patch component changed (1.2.3 → 1.2.7)
   - `minor` — minor component changed (1.2.x → 1.5.0)
   - `major` — major component changed (1.x → 2.0)
   - `prerelease`/`other` — anything weird (treat as major for risk purposes)

3. **Group packages.** Apply these heuristics in order:

   **Known ecosystems** (group these together regardless of prefix):
   - React core: `react`, `react-dom`, `react-is`, `@types/react`, `@types/react-dom`, `scheduler`
   - Next.js: `next`, `eslint-config-next`, `@next/*`
   - Vue: `vue`, `@vue/*`, `vue-router`, `pinia`
   - Svelte: `svelte`, `@sveltejs/*`
   - ESLint: `eslint`, `eslint-config-*`, `eslint-plugin-*`, `typescript-eslint`, `@typescript-eslint/*`
   - TypeScript core: `typescript`, `tslib`, `@types/node`
   - Vite: `vite`, `@vitejs/*`, `vite-plugin-*`
   - Webpack: `webpack`, `webpack-cli`, `webpack-dev-server`, `@webpack-cli/*`
   - Rollup: `rollup`, `@rollup/*`, `rollup-plugin-*`
   - Testing: `vitest`, `@vitest/*`, `jest`, `ts-jest`, `babel-jest`, `@types/jest`, `@testing-library/*`, `happy-dom`, `jsdom`, `playwright`, `@playwright/*`
   - Tailwind: `tailwindcss`, `@tailwindcss/*`, `postcss`, `autoprefixer`
   - Redux: `@reduxjs/toolkit`, `react-redux`, `redux`, `redux-persist`, `reselect`
   - MDX: `@mdx-js/*`, `next-mdx-*`, `remark-*`, `rehype-*`, `unified`
   - Storybook: `storybook`, `@storybook/*`
   - Babel: `@babel/*`, `babel-loader`
   - UI kits: `@radix-ui/*`, `@mantine/*`, `@mui/*`, `@chakra-ui/*`, `@headlessui/*`
   - State: `zustand`, `jotai`, `valtio`, `recoil`
   - Database/ORM: `prisma`, `@prisma/*`, `drizzle-orm`, `drizzle-kit`, `dexie`, `dexie-react-hooks`, `mongoose`, `typeorm`

   **Scope prefix fallback:** any `@scope/*` packages not in a known ecosystem above get grouped by their scope (e.g., all unmatched `@aws-sdk/*` together).

   **Standalone:** anything left over is its own group.

4. **Present the discovery summary** to the user:
   - Total outdated packages, counts by bump tier
   - Grouped listing with `current → target` versions and bump type for each package
   - Note any "weird" version transitions (e.g., 0.x → 1.0 majors that imply API stabilization)

## Phase 2 — Audit & Research

### Snyk baseline

Run `snyk test` and record the baseline:
- Total vulnerabilities split by severity (critical / high / medium / low)
- Which direct dependencies introduce them

This is your reference point for measuring whether the upgrades improved or worsened the security posture.

### Web research per group

For each group, research the target versions with web search and targeted fetches:

**Patch / minor bumps (lightweight):**
- Search: `"<package> <version> changelog"` — release notes
- Search: `"<package> <version> regression"` OR `"<package> <version> bug"` — known issues
- Fetch the GitHub releases page if available

**Major bumps (deeper):**
- Everything above, plus:
- Search: `"<package> v<major> migration guide"`
- Search: `"<package> <version> breaking changes"`
- Check community signal (Stack Overflow, Reddit, GitHub Discussions) — high-volume complaints in the last 30 days are a red flag

Summarize findings per group: breaking changes, migration steps needed, regressions reported, peer-dep implications. Be honest about uncertainty — "I couldn't find a migration guide" is more useful than fabricating one.

## Phase 3 — Plan

Sequence the groups for upgrade:

1. **Patch tier first** (lowest risk — bug fixes only).
2. **Minor tier second** (additive changes, should be backward-compatible).
3. **Major tier last** (breaking changes — these are where things go wrong).

Within each tier, order by independence: groups that nothing else depends on go first. (For example, a dev-only testing group can usually run before a runtime UI group.)

For each group, document:
- Packages and version transitions (`<current> → <target>`)
- Research findings and any migration notes
- Peer dependency considerations (flag potential conflicts)
- Risk assessment: **low / medium / high**, with a one-line justification

**Where to write the plan:**
- Prefer `docs/plans/YYYY-MM-DD-dependency-upgrade.md` if `docs/plans/` already exists.
- Otherwise check for `docs/`, `plans/`, or `.plans/` and use whichever exists.
- If none exist, write to `DEPENDENCY-UPGRADE-PLAN.md` at the project root and tell the user where it went.

Present the plan and ask: **"Plan ready at `<path>`. Want me to execute this now, or would you prefer to review and run it later?"**

If the user defers, stop here.

## Phase 4 — Execution (group by group)

**Git strategy.** No commits are made until all groups are complete. All changes remain uncommitted during execution so rollback via `git checkout --` works cleanly. Don't `git stash` mid-flow either — that masks failures.

For each group, in the planned order:

1. **Upgrade the packages.** Build a single command that includes all packages in the group, preserving the dev/prod split. Maintain caret (`^`) range convention unless the existing `package.json` shows different patterns (e.g., pinned exact versions or `~` ranges) — match what's already there.

   Example pnpm: `pnpm add react@^19.0.0 react-dom@^19.0.0 && pnpm add -D @types/react@^19.0.0 @types/react-dom@^19.0.0`
   Example npm: `npm install react@^19.0.0 react-dom@^19.0.0 && npm install --save-dev @types/react@^19.0.0 @types/react-dom@^19.0.0`

2. **Check peer deps.** If install fails with peer dependency conflicts:
   - Report the exact conflict
   - Suggest resolution (version adjustment, or for npm: `--legacy-peer-deps`; for pnpm: `--no-strict-peer-dependencies`)
   - **Ask the user before proceeding** — peer overrides can mask real incompatibilities

3. **Run gates** in this order, stopping on first failure:
   - `<pm> build` (if script exists)
   - `<pm> lint` (if script exists)
   - `<pm> typecheck` (if script exists)
   - `<pm> test` (if script exists)

4. **Snyk re-audit.** Run `snyk test`. Compare against the Phase 2 baseline.

5. **Report group results:**
   - Build / Lint / Typecheck / Tests: pass or fail (include failure detail)
   - Snyk delta: vulnerabilities added / resolved vs. baseline (by severity)

6. **Approval gate.** Ask: **"Group <N> (`<name>`) complete. Continue to next group?"**

### On failure at any verification step

Roll back this group's changes:

```bash
# pnpm
git checkout -- package.json pnpm-lock.yaml && pnpm install

# npm
git checkout -- package.json package-lock.json && npm install
```

Report what failed (which gate, what the error looked like, your best guess at why). Then ask whether to:
- **Skip this group** and continue with the next one
- **Investigate** (read the error more carefully, try a narrower upgrade within the group)
- **Stop entirely** and let the user take over

Don't silently retry. Don't downgrade to bypass. Don't add `--force` flags without explicit user permission.

## After all groups

1. Run final `snyk test` and compare to baseline.
2. Summarize all changes:
   - Packages upgraded (with version transitions)
   - Vulnerabilities resolved (and any new ones introduced)
   - Groups skipped, with reason
3. **Commit** (only `package.json` and the relevant lockfile — don't sweep in unrelated changes):

   ```bash
   # pnpm
   git add package.json pnpm-lock.yaml

   # npm
   git add package.json package-lock.json
   ```

   ```bash
   git commit -m "$(cat <<'EOF'
   chore: upgrade dependencies — <one-line summary>

   <bulleted list of package -> version transitions, grouped>

   Snyk audit: <baseline count> → <final count> vulnerabilities

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

   Tailor the commit subject to what actually happened. If only one group ran, name it (`upgrade React 18 → 19`). If many groups ran, summarize by theme (`upgrade build, testing, and UI deps`).

## Failure-mode notes

- **Lockfile drift.** If `<pm> install` produces a lockfile diff even before you touch `package.json`, the lockfile was already out of sync with `package.json`. Surface this to the user before proceeding — fixing drift is a separate task.
- **Workspaces / monorepos.** If `package.json` declares `workspaces` (npm) or there's a `pnpm-workspace.yaml`, this skill's current heuristics target the root package only. Tell the user that monorepo upgrades need per-workspace planning, and ask whether to proceed at the root only or stop.
- **Engine constraints.** If a target version requires a Node version above what's specified in `engines.node` or `.nvmrc`, flag it in the plan and ask before upgrading — silently breaking the Node floor is worse than skipping the bump.
- **Yanked/deprecated packages.** If a package shows as deprecated in `npm outdated`, surface that — sometimes the right move is to replace it, not bump it.
