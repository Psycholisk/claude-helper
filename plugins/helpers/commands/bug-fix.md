---
description: Guided bug fixing with reproduction-first, root-cause analysis, and mandatory regression tests
argument-hint: Bug ticket URL/ID (Shortcut, GitHub issue, Jira, Linear, Trello, etc.) or free-form description
---

# Bug Fix

You are helping a developer fix a bug. Bug work is **diagnostic, not architectural** — it flows inward from symptom → reproduction → root cause → minimal fix → regression guard. Follow the phases below; do not skip ahead.

## Core Principles

- **Reproduce before fixing.** A bug you can't reproduce is a bug you can't verify. If you can't reproduce it, stop and report — don't guess.
- **Test-first when feasible.** Write a failing test that captures the bug *before* writing the fix. The test failing proves you understood the bug; the test passing proves the fix works. This collapses reproduction and regression-guard into one artifact.
- **Tests are mandatory.** Bugs cluster in untested or poorly-tested code — that's why the bug exists. Every fix ships with a regression test, plus thin coverage for the surrounding area when it's bare. The PR is blocked without tests unless the user explicitly waives them with a written reason.
- **Root cause, not symptom.** Distinguish the surface failure from the underlying cause. Fix the cause. Document both.
- **Minimal fix, no drive-bys.** Smallest change that resolves the root cause. Boy Scout cleanups in the same file are fine; refactoring sprees are not.
- **Phase gates.** Pause for user confirmation at the gates marked **CHECKPOINT** below. Don't barrel through.
- **Use TodoWrite** to track all phases.

---

## Phase 1: Intake & Evidence Gathering

**Goal**: Build a tight bug brief — what's broken, how to see it, who's affected.

Initial input: $ARGUMENTS

**Actions**:
1. Create a todo list covering all phases.
2. **Resolve the input** — detect the source and fetch what you can. The input may come from any tracker:
   - **Shortcut** (`sc-12345`, `app.shortcut.com/...`): if a Shortcut MCP is available (e.g., `mcp__shortcut__stories-get-by-id`), fetch the story, its comments, attachments, and linked PRs.
   - **GitHub issue** (`github.com/<org>/<repo>/issues/<n>`): use `gh issue view <n> --repo <org>/<repo> --comments` to fetch the issue and discussion.
   - **Jira / Linear / Trello / other tracker**: if no MCP or CLI is available for the tracker, ask the user to paste the ticket description and any comments, or to share access details. Don't fabricate ticket content.
   - **Free-form description**: use the description as-is and proceed.
   - **Unknown URL**: try `WebFetch` to read the page, but ask the user to confirm the content if anything looks off (auth-walled trackers will return login pages).
3. Extract from the ticket/description (whichever fields are present):
   - Expected vs. actual behavior
   - Reproduction steps (if provided)
   - Environment (production, staging, local, specific tenant/account)
   - Severity / blast radius hints
   - When first reported
   - Any linked commits, PRs, or prior fixes
4. **Prompt the user for supporting evidence.** Don't assume the ticket has it. Ask explicitly:
   > "Do you have any supporting tracing or evidence — error tracker (Sentry/Rollbar/Bugsnag) link, log query (Grafana/Loki/Datadog/CloudWatch), screenshots, video, Slack thread, stack trace, or anything else? If not, I'll work from what's in the ticket."
5. If the user provides evidence, fetch what you can:
   - **Error tracker links**: open the page, summarize the error, frequency, affected users/sessions.
   - **Log queries**: run them with whatever tool the project uses (project's CLAUDE.md / README usually documents this — e.g., `logcli`, `aws logs`, `gcloud logging read`, dashboard URL).
   - **Live pod/container logs**: tail with whatever tool fits (e.g., `kubectl logs -f`, `docker logs -f`).
   - **Stack traces**: identify the relevant frames in the project's codebase.
6. Present the **bug brief** back to the user:
   - One-paragraph summary of the bug
   - Repro steps (best understanding so far)
   - Evidence collected
   - Open questions / low-confidence areas

**CHECKPOINT**: If the brief is ambiguous or under-specified, ask clarifying questions and wait for answers before proceeding. Specific, concrete questions only — no "what do you want?".

---

## Phase 2: Reproduce via Failing Test

**Goal**: Prove the bug exists in a way that will keep proving its absence forever.

**Actions**:
1. **Default path — test-first**: write a failing test that reproduces the bug.
   - Use the project's test framework. Check the project's `CLAUDE.md`, `README`, `package.json`, `Makefile`, or equivalent to find the right command (e.g., `pytest`, `jest`, `go test`, `cargo test`, `rspec`, or a project-specific wrapper).
   - Place the test in the conventional location for the affected code.
   - Run it; confirm it fails *for the right reason* (not a setup error). If it fails for the wrong reason, fix the test until the failure mode matches the actual bug.
2. **Fallback — manual reproduction**: if a test-first repro isn't feasible (race conditions, hard-to-mock external integrations, UI timing, missing fixtures), reproduce manually:
   - Use the project's API testing tool, browser, CLI, or whatever fits the surface where the bug appears.
   - Use the local app, staging, or whatever environment is appropriate (and authorized).
   - Capture exactly what you did and what happened.
   - **Commit upfront** to writing tests post-fix in Phase 7. Make this explicit to the user.
3. **If you cannot reproduce at all**: STOP. Report to the user with what you tried and what you'd need (more repro steps, access to a specific environment, a customer-side artifact). Do not proceed to fix.

**Output**: a failing test (preferred) or a documented manual repro + a commitment to add tests after the fix.

---

## Phase 3: Localize & Coverage Audit

**Goal**: Find the code path involved and assess how well it's tested.

**Actions**:
1. Launch a code-exploration agent (e.g., `feature-dev:code-explorer` if available, or the `Explore` / general-purpose agent) to trace the code path. Brief it with the bug brief and any stack frames. Ask it to return:
   - The handler/function/method where the bug lives
   - The call chain leading to it
   - Adjacent code that shares the same failure mode (so we know the blast radius)
   - 5–10 key files to read
2. Read the files the agent identifies. Don't take its summary on faith — verify in source.
3. **Coverage audit on the affected area**: check whether the function/handler/path involved has tests. Don't audit the whole module — just the immediate surroundings. Record:
   - Does the buggy function have any tests today?
   - Do adjacent functions in the same file have tests?
   - Are there obvious cases that should have caught this class of bug but didn't?
4. Run `git blame` on the buggy lines to find:
   - Introducing commit + PR + author
   - Whether the bug was always there or introduced by a specific change
   - Any related context in the commit message

---

## Phase 4: Root Cause Analysis

**Goal**: Distinguish symptom from cause, and propose a minimal fix.

**Actions**:
1. Write a short analysis covering:
   - **Symptom** — what the user sees
   - **Root cause** — what's actually wrong in the code (logic error, missing validation, race, config drift, integration mismatch, dependency contract change, etc.)
   - **Why it wasn't caught** — what test or guard would have caught it
   - **Proposed fix** — the minimal change at the root cause
   - **Blast radius** — how long has this been broken, who's affected, is it live in production?
2. **CHECKPOINT**: present the analysis to the user. Wait for confirmation before implementing. This is the most important checkpoint — bug fixes go wrong here, and re-doing a wrong fix is expensive.

---

## Phase 5: Branch / Worktree Setup

**Goal**: Isolate the work on a fresh branch.

**Actions**:
1. Confirm we're on a clean working tree, not in the middle of unrelated changes.
2. Identify the project's default integration branch — usually `main`, sometimes `develop` or another. Check `git remote show origin | grep "HEAD branch"` if unsure. **Never target a deploy branch (`staging`, `production`, etc.) for a PR.**
3. Update the default branch:
   ```bash
   git checkout <default-branch> && git pull origin <default-branch>
   ```
4. **Branch name** — adapt to the ticket source detected in Phase 1:
   - Shortcut: `sc-<ticket-id>/<short-kebab-description>`
   - GitHub issue: `fix/issue-<n>-<short-kebab-description>`
   - Jira / Linear: `fix/<ticket-key>-<short-kebab-description>` (e.g., `fix/PROJ-123-checkout-validation`)
   - No ticket: `fix/<short-kebab-description>`
   - If the project has its own branch convention documented in `CLAUDE.md` or contributing docs, follow that instead.
5. **If the project uses git worktrees** (check for an existing `../worktrees/` directory or a documented convention), create the branch as a worktree:
   ```bash
   git worktree add ../worktrees/<app-name>/<branch-name> -b <branch-name>
   ```
   Otherwise just create the branch normally:
   ```bash
   git checkout -b <branch-name>
   ```
6. Move the failing test from Phase 2 onto the new branch if it was written outside.

---

## Phase 6: Implement Minimal Fix

**Goal**: Smallest change that fixes the root cause.

**Actions**:
1. Make the change. Stay scoped to the root cause. No refactoring sprees.
2. Apply the Boy Scout Rule lightly — fix obvious nearby cruft (misleading variable name, dead import, stale comment) but don't expand scope.
3. Add a comment if the fix is non-obvious — guards against a subtle invariant, works around a specific upstream bug, encodes a domain rule. Skip comments for self-evident changes.
4. Follow project conventions strictly (look at neighboring code).

---

## Phase 7: Verify & Backfill Tests

**Goal**: Prove the fix works and that the area won't regress.

**Actions**:
1. Run the failing test from Phase 2. It must now pass.
2. **If Phase 2 used the manual-repro fallback**: write the regression test now. This is the test you committed to. Don't ship without it.
3. **Backfill coverage** for the affected area based on Phase 3's audit. Keep it scoped:
   - One or two tests covering the obvious adjacent cases that should have caught this class of bug
   - Not a comprehensive test suite for the module — just the gap that let this bug through
4. **Test naming & traceability**: name the regression test so future-us can trace why it exists. Add a comment if naming alone isn't enough:
   ```
   // Regression: <ticket-ref> — <one-line bug summary>
   ```
   `<ticket-ref>` is whatever applies: `sc-12345`, `gh-issue-#42`, `PROJ-123`, or just the bug summary if there's no ticket.
5. Re-run the original manual repro path (if applicable) to confirm the fix end-to-end.
6. **Run only tests for affected areas** — not the full suite, unless the project's CI norms or the user explicitly ask for it. Use whatever scoping the test runner supports (e.g., `pytest path/`, `jest --testPathPattern=...`, `go test ./affected/...`).

**Hard rule**: if no test was added and the user hasn't explicitly waived tests with a written reason, do not proceed to PR. Stop and surface this.

---

## Phase 8: Self-Review

**Goal**: Catch issues before review, not after.

**Actions**:
1. Launch a code-review agent (e.g., `feature-dev:code-reviewer` if available, otherwise the general-purpose agent) on the diff. Brief it with:
   - The bug brief
   - The root cause from Phase 4
   - The diff
2. Ask it to flag: bugs in the fix, unintended scope creep, missing edge cases, regressions in adjacent code, convention violations.
3. Present findings to the user; address based on their decision (fix now / fix later / proceed as-is).

---

## Phase 9: Pull Request

**Goal**: Open a PR that gives reviewers everything they need.

**Actions**:
1. Confirm the target branch — the project's default integration branch (usually `main`, sometimes `develop`). **Never target a deploy branch like `staging` or `production`.**
2. Stage and commit. Use a clear commit message that includes the ticket reference if there is one:
   ```
   fix(<area>): <short summary> [<ticket-ref>]
   ```
   Drop the bracket if there's no ticket.
3. Push the branch with `-u`.
4. Open the PR with this body structure:

   ```markdown
   ## Business Value
   <Why this matters — who was affected, what was broken, what's now fixed.
   If the user didn't supply business value, ASK before opening the PR.>

   ## Root Cause
   <One paragraph: what was actually wrong, distinct from the symptom.>

   ## Fix
   <One paragraph: what changed and why this is the minimal correct fix.>

   ## Tests Added
   - <Regression test: name + what it covers>
   - <Coverage backfill tests, if any>
   <If tests were waived: explain why explicitly.>

   ## Blast Radius
   <How long was this broken? Who/what was affected? Is it live in production?
   Any related areas reviewers should double-check?>

   ## Verification
   - [x] Regression test fails before fix, passes after
   - [x] Affected-area tests pass
   - [ ] <Any manual verification reviewers should do>

   <Ticket link, if any. Examples:
     Closes #42
     Closes [sc-12345](<shortcut-url>)
     Refs [PROJ-123](<jira-url>)>
   ```
5. If the tracker supports linking back to the PR (e.g., Shortcut external links, Jira smart commits, Linear magic words), do so.

---

## Phase 10: Summary

**Actions**:
1. Mark all todos complete.
2. Summarize for the user:
   - Root cause + fix in two sentences
   - Tests added
   - PR URL
   - Anything that wasn't fixed and was deliberately left for follow-up

---

## What this skill will not do

- Skip reproduction in the name of speed
- Write the fix and the regression test simultaneously (test must fail first, then pass)
- Bypass with `--no-verify` or similar shortcuts
- Widen scope beyond the bug
- Open a PR without tests (unless explicitly waived with a reason)
- Target a deploy branch (`staging`, `production`, etc.) as a PR base
