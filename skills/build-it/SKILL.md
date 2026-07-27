---
name: build-it
description: End-to-end autonomous delivery of a Shortcut ticket. Use when the user says "build it", "/build-it sc-XXXX", "ship this ticket", or wants a ticket implemented, PR'd, merged to staging, and made green with review comments resolved — leaving only QA + deploy for the human. Composes the native /goal autonomous loop with /feature-dev (implementation) and /fix-pr-comments (PR review fixes).
argument-hint: A Shortcut ticket (sc-XXXX) or its URL
version: 0.1.0
---

# build-it — autonomous ticket → staging pipeline

Take a Shortcut ticket and drive it all the way to a state where **the only things left for the human are QA and deploy**. You implement it, open the PR against the default branch, merge the changes to staging for QA, get the pipeline green, and resolve the automated Claude review comments — running autonomously and interrupting the user only for decisions you genuinely cannot make.

**End state you are responsible for reaching:**
1. Feature implemented on a worktree branch, local quality review passed.
2. PR opened against the repo's **default integration branch** (never staging, never merged to main).
3. Branch merged into **staging** (direct git merge + push) so the human can QA.
4. **All CI/pipeline checks green.**
5. The automated **Claude PR review** has run and its comments are resolved.
6. Shortcut ticket moved to **Ready for QA** with a summary comment.

Input ticket: `$ARGUMENTS`

---

## How this skill runs autonomously

This skill is built on the native **`/goal`** command (Claude Code v2.1.139+). `/goal` sets a completion condition and keeps starting new turns until a fast evaluator confirms the condition holds. Two facts shape how we use it:

- The evaluator **only judges what is visible in the transcript** — it cannot run commands. So every part of the contract must be something you *prove* by surfacing command output (e.g. paste `gh pr checks` showing all green).
- `/goal` will start another turn even if you tried to ask a question. So when you hit a **stop-and-ask condition** (below), you MUST run `/goal clear` and return to the user — do not rely on a normal question pausing the loop.

### Step A — set up the goal

First do **Phase 0** (setup) below so you know the ticket, repos, and branch. Then recommend the user enable **auto mode** for a truly unattended run (tell them: "Enable auto mode so I don't stop on every tool call"), and set the goal with a contract like this (fill in the specifics; keep under 4000 chars):

```
/goal Ticket <sc-XXXX> is fully delivered to staging. This holds ONLY when the transcript shows ALL of: (1) the feature implemented and local quality review clean; (2) `gh pr view` shows an OPEN PR against the default branch (main/develop), NOT staging; (3) `git push` output shows the branch merged into staging for each affected repo; (4) `gh pr checks <PR>` shows every check GREEN; (5) the automated Claude review has run and `gh` shows no unresolved review comments; (6) the Shortcut ticket is in "Ready for QA". Do NOT merge to main. Constraints: only run tests for affected areas; never force-push over someone else's staging work without verifying. STOP and clear the goal if a critical/architectural decision, unresolvable ambiguity, or destructive/irreversible action is required — or after 40 turns.
```

Then execute the phases in order. If you were invoked without `/goal` being available (older CLI, hooks disabled), just run the phases directly and tell the user the loop won't auto-continue between turns.

---

## Operating rules — when to run solo vs. ask

**Default: run solo and non-intrusively.** In the vast majority of cases you can figure it out. Do not narrate every micro-decision or ask permission for routine work.

**STOP, run `/goal clear`, and ask the user only when:**
- A **mid-to-large architectural decision** has real trade-offs and would be expensive to reverse (new service, data-model/schema change, cross-repo contract change, choosing between materially different approaches).
- The ticket is **genuinely ambiguous** on something that changes the implementation and you cannot resolve it from the codebase, the ticket, or linked threads.
- An action is **destructive or irreversible** and not already authorized (deleting data, merging to main, force-pushing over others, touching production).
- CI keeps failing on the **same step after 3 fix attempts** (see Phase 5).

When you stop, present the decision crisply with your recommendation and concrete options, so the user can accept, redirect, or answer in one reply. After they respond, re-set the goal and continue.

**Optional single design checkpoint:** if — and only if — you judge the architecture non-obvious enough to be worth one confirmation, present the chosen approach once before implementing, then proceed autonomously. Skip it for small/clear tickets.

---

## Phase 0 — Setup

1. **Read the ticket** via Shortcut MCP: `mcp__shortcut__stories-get-by-id`. Capture title, description, acceptance criteria, tasks, comments, and any linked repos/PRs.
2. **Move ticket to In Progress** (`stories-update` → workflow_state_id `500001434`) and assign to the user if unassigned.
3. **Identify affected repo(s).** A ticket may touch more than one repo (e.g. invoicer + quiqup-platform + salesforce-to-kafka). Determine them from the ticket and codebase. Handle each repo independently through Phases 3–6.
4. **Create a worktree per repo** (never work on `main`):
   - From the repo's main dir: `git checkout main && git pull origin main`, ensure `../worktrees/` exists.
   - Branch name: `<type>/sc-<id>/<short-kebab-desc>` where type ∈ `feat|fix|chore|refactor|docs` (type prefix goes **before** the sc id).
   - `git worktree add ../worktrees/<app>/<branch> -b <branch>`, cd in, install deps.

---

## Phase 1 — Implement (autonomous /feature-dev)

Run the **`/feature-dev`** workflow, but in an **autonomous variant** — its normal approval gates are collapsed under the operating rules above:

- Phase 1–2 (Discovery, Codebase Exploration): do fully — launch code-explorer agents, read the key files they return.
- Phase 3 (Clarifying Questions): **resolve ambiguities yourself** from the codebase and ticket. Only stop-and-ask per the operating rules if genuinely blocking.
- Phase 4 (Architecture Design): decide the best approach yourself. Use the optional single design checkpoint only if warranted.
- Phase 5 (Implementation): implement following codebase conventions strictly. Apply the Boy Scout rule; leave targeted comments where future-you would otherwise re-derive context.

---

## Phase 2 — Local quality review

Run `/feature-dev` Phase 6: launch the 3 code-reviewer agents (simplicity/DRY, bugs/correctness, conventions). **Auto-fix high-severity and clearly-correct issues.** Only surface a review finding to the user if it implies a stop-and-ask architectural decision.

---

## Phase 3 — Commit, push, open PR (per repo)

1. Run the repo's formatter/linter before committing (e.g. `gofmt` for Go repos like quiqup-platform — lint CI fails on struct-alignment diffs otherwise). Only run tests for **affected areas**, not the whole suite.
2. Commit with clear messages. Add a **one-line** CHANGELOG entry if the repo uses one (engineering detail goes in the PR body, not the changelog).
3. Determine the **default integration branch**: `git remote show origin | grep "HEAD branch"` (usually `main`; some repos use `develop`, e.g. track-parcel). **Never target `staging`.**
4. Push the branch and open the PR against the default branch with `gh pr create`. The PR body **must include the business value** (why this matters, from the ticket) plus what/how, testing notes, and the `sc-XXXX` link. If business value isn't clear from the ticket, that's a stop-and-ask.
5. Add the PR as an external link on the Shortcut ticket.

---

## Phase 4 — Merge to staging for QA (per repo)

"Merge to staging" means a **direct git merge + push to the `staging` branch — NOT a PR targeting staging.**

1. `git checkout staging && git pull origin staging`, merge the feature branch in, push.
2. Staging is a shared QA branch and **can be force-pushed during deploy-fixes** — after pushing, verify your merge actually survived (re-fetch and confirm your commits are present). If a conflict or clobber occurred, resolve and re-push.
3. Surface the push output in the transcript (the goal contract checks for it).

---

## Phase 5 — Get the pipeline green (per PR)

Poll the PR checks and fix failures until everything is green:

- `gh pr checks <PR> --watch` / `gh run list` / `gh run view <id> --log-failed` to see what failed.
- Distinguish **real failures** (your code) from **known flakes** — several repos have documented flaky tests (e.g. quiqup-platform coverage-CI flakes, ex-core-api CreateOrderController, invoicer lint OOM). For a known flake, **re-run the job** rather than "fixing" passing code; note it.
- Fix real failures, push, re-check.
- **Cap: after 3 fix attempts on the same failing step**, stop — run `/goal clear` and present the failure to the user with what you've tried.

---

## Phase 6 — Resolve the automated Claude PR review

1. **Wait for the automated Claude review** to post on the PR (a GitHub Action / review bot). Poll `gh pr view <PR> --json reviews,comments` and `gh api repos/{owner}/{repo}/pulls/{n}/reviews` until the Claude review appears and has finished.
2. **Auto-detect the bot's handle** from the review authors (e.g. an app/bot login containing `claude`). If no automated Claude review exists on this repo, note it and skip to Phase 7.
3. Run **`/fix-pr-comments <PR_URL> <claude-review-handle>`** to address its comments: firm fixes applied and replied to automatically; discretionary items only escalate to the user if they hit a stop-and-ask criterion.
4. Push fixes, then loop back through Phase 5 (green) — new commits re-trigger CI.

---

## Phase 7 — Finalize (hand off for QA + deploy)

1. Move the Shortcut ticket to **Ready for QA** (`stories-update` → workflow_state_id `500001440`).
2. Post a summary comment on the ticket and to the user covering: what was built, key decisions, affected repos + PR links, that changes are **on staging ready to QA**, and the pipeline/review status.
3. **Leave the PR open against the default branch. Do NOT merge to main and do NOT deploy** — those require the human's explicit action after QA.
4. Once the ticket is Ready for QA and all contract conditions are surfaced, the `/goal` evaluator will clear the goal. Tell the user exactly what's left: **QA on staging, then merge/deploy.**

---

## Never do
- Never merge to `main` (or the default branch) without explicit user approval.
- Never open a PR that targets `staging`.
- Never deploy to production.
- Never run the full test suite when only a subset is affected.
- Never force-push over someone else's work without verifying and flagging it.
