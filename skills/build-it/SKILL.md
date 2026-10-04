---
name: build-it
description: End-to-end autonomous delivery of a ticket from any tracker (Shortcut, Linear, GitHub Issues, Jira). Use when the user says "build it", "/build-it <ticket>", "ship this ticket", or wants a ticket implemented, PR'd, merged to staging, and made green with review comments resolved — leaving only QA + deploy for the human. Resolves the project's tracker, connection and credentials from a per-project profile, then composes the native /goal autonomous loop with /feature-dev (implementation), /pr-review (when CI has no code-reviewer step) and /fix-pr-comments (review fixes).
argument-hint: A ticket id or URL (sc-123, ENG-42, #123, PROJ-7)
version: 0.3.0
---

# build-it — autonomous ticket → staging pipeline

Take a ticket and drive it all the way to a state where **the only things left for the human are QA and deploy**. You implement it, open the PR against the default branch, merge the changes to staging for QA, get the pipeline green, and resolve the PR review comments — running autonomously and interrupting the user only for decisions you genuinely cannot make.

**End state you are responsible for reaching:**
1. Feature implemented on a worktree branch, local quality review passed.
2. PR opened against the repo's **default integration branch** (never staging, never merged to main).
3. Branch merged into **staging** (direct git merge + push) so the human can QA.
4. **All CI/pipeline checks green.**
5. A **PR review has run** — CI's reviewer if the repo has one, otherwise `/pr-review` run by you — and its comments are resolved.
6. Ticket moved to the project's **hand-off state** (e.g. "Ready for QA") with a summary comment — or, if the tracker has no such state, a hand-off comment.

Input ticket: `$ARGUMENTS`

This skill is project-agnostic. Everything that differs between projects — which tracker, how to connect to it, where the credentials live, which workflow states to use, branch naming, how staging deploys, how to QA — comes from the **project profile** resolved in Phase 0. Never hardcode a workspace's state IDs, team IDs, hostnames or tokens into this file: it is shared across projects and machines.

---

## How this skill runs autonomously

This skill is built on the native **`/goal`** command (Claude Code v2.1.139+). `/goal` sets a completion condition and keeps starting new turns until a fast evaluator confirms the condition holds. Two facts shape how we use it:

- The evaluator **only judges what is visible in the transcript** — it cannot run commands. So every part of the contract must be something you *prove* by surfacing command output (e.g. paste `gh pr checks` showing all green).
- `/goal` will start another turn even if you tried to ask a question. So when you hit a **stop-and-ask condition** (below), you MUST run `/goal clear` and return to the user — do not rely on a normal question pausing the loop.

### Step A — set up the goal

First do **Phase 0** (resolve the project profile, then setup) so you know the tracker, the ticket, the repos, and the branch. Then recommend the user enable **auto mode** for a truly unattended run (tell them: "Enable auto mode so I don't stop on every tool call"), and set the goal with a contract like this (fill in the specifics from the profile; keep under 4000 chars):

```
/goal Ticket <TICKET> is fully delivered to staging. This holds ONLY when the transcript shows ALL of: (1) the feature implemented and local quality review clean; (2) `gh pr view` shows an OPEN PR against the default branch (main/develop), NOT staging; (3) `git push` output shows the branch merged into staging for each affected repo; (4) `gh pr checks <PR>` shows every check GREEN, or shows that the repo has no checks; (5) the transcript shows whether CI has a code-reviewer step, and — if it does not — that /pr-review was run on the PR right after it was opened; either way `gh` shows no unresolved review comments; (6) the <TRACKER> ticket is in "<HAND-OFF STATE>" (or, if the tracker has none, a hand-off comment is posted). Do NOT merge to main. Constraints: only run tests for affected areas; never force-push over someone else's staging work without verifying. STOP and clear the goal if a critical/architectural decision, unresolvable ambiguity, or destructive/irreversible action is required — or after 40 turns.
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
- The project profile can't be resolved, or the tracker **connection or credentials are missing** (see Phase 0). Say exactly what's missing; never go hunting for credentials elsewhere on the machine.

When you stop, present the decision crisply with your recommendation and concrete options, so the user can accept, redirect, or answer in one reply. After they respond, re-set the goal and continue.

**Optional single design checkpoint:** if — and only if — you judge the architecture non-obvious enough to be worth one confirmation, present the chosen approach once before implementing, then proceed autonomously. Skip it for small/clear tickets.

---

## Phase 0 — Resolve the project, then set up

### 0.1 Resolve the project profile

A **project profile** is a short markdown file that says, for one project on this machine: which tracker it uses, how to connect, where the credentials come from, which workflow states mean what, and the project's delivery conventions. Profiles are **machine-local** — they live in `~/.claude/build-it/projects/<project>.md`, outside this repo, because connection details and credential paths differ per machine and must never be committed to a shared skill. The template is [`project-profile.template.md`](project-profile.template.md).

Resolve it in this order and **stop at the first match**:

1. **Local profile.** List `~/.claude/build-it/projects/*.md` and pick the one whose `match` section fits — the current working directory is under one of its `paths`, a repo's `git remote get-url origin` matches one of its `remotes`, or the ticket matches its `ticket_pattern`. If more than one matches, prefer the path match.
2. **The project's own docs.** No profile? Read the project's `CLAUDE.md` (and the spec/root repo's `CLAUDE.md` if the app repo defers to one). Many projects already state their tracker, workflow states, branch convention and staging flow there.
3. **Infer from the ticket** using the table in [`trackers.md`](trackers.md) (`sc-123` → Shortcut, `ENG-42` → Linear, `#123` / GitHub issue URL → GitHub Issues, `PROJ-7` with a Jira URL → Jira), and **discover workflow states by name** at runtime instead of assuming IDs.

If you got here via 2 or 3, tell the user once at the end which details you inferred, and offer to save them as a profile so the next run is deterministic.

Project-level instructions (the project's `CLAUDE.md`) **override** this skill where they conflict — for example a project that wants every rule a ticket decides written into its spec repo, or that limits which ticket ids may appear in commit messages.

### 0.2 Connect to the tracker

Follow the adapter for the profile's tracker in [`trackers.md`](trackers.md). The rules for every tracker:

- **Credentials come only from where the profile says** — an MCP server that is already connected, or an environment variable loaded by the profile's `load` command (e.g. `. ~/.config/<project>/tracker.env`). Never read tokens out of other projects' files, shell history, transcripts or browser stores, and never print a token.
- **Prefer the profile's stated connection**; if it says "MCP if available, else REST", check with ToolSearch for the MCP first.
- **Verify the connection before doing anything else**: fetch the ticket. If that fails (no MCP, empty env var, 401/403), stop and tell the user exactly which credential or connector is missing.

### 0.3 Read the ticket and start it

1. **Read the ticket**: title, description, acceptance criteria, tasks/checklist, comments, and any linked repos/PRs.
2. **Move it to the profile's `start` state** (usually "In Progress") and assign it to the user if unassigned and the tracker supports it.
3. **Identify affected repo(s).** A ticket may touch more than one repo. Determine them from the ticket, the profile and the codebase. Handle each repo independently through Phases 3–6.
4. **Create a worktree per repo** (never work on `main`), following the profile's `worktrees` location if it gives one, otherwise:
   - From the repo's main dir: `git checkout main && git pull origin main`, ensure `../worktrees/` exists.
   - Branch name: the profile's `branch` pattern; if none, `<type>/<ticket-id>/<short-kebab-desc>` with the type prefix **before** the ticket id. Some trackers generate one for you (Shortcut's `formatted_vcs_branch_name`, Linear's `branchName`) — prefer it when the profile says so.
   - `git worktree add <worktrees>/<branch> -b <branch>`, cd in, install deps.

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

1. Run the repo's formatter/linter before committing (e.g. `gofmt` for Go repos, where lint CI often fails on formatting diffs). Only run tests for **affected areas**, not the whole suite.
2. Commit with clear messages that reference the ticket the way the profile says. Add a **one-line** CHANGELOG entry if the repo uses one (engineering detail goes in the PR body, not the changelog).
3. Determine the **default integration branch**: `git remote show origin | grep "HEAD branch"` (usually `main`; some repos use `develop`). If the profile names it, trust the profile — a repo's GitHub default branch is sometimes stale. **Never target `staging`.**
4. Push the branch and open the PR against the default branch with `gh pr create`. The PR body **must include the business value** (why this matters, from the ticket) plus what/how, testing notes, and the ticket link. If business value isn't clear from the ticket, that's a stop-and-ask.
5. Link the PR on the ticket (see the adapter — some trackers link automatically from the branch name or PR text).
6. **Immediately decide who reviews this PR** (see 3.1) and, if that's you, **run `/pr-review` now** — before staging, before the pipeline, before `/fix-pr-comments`.

### 3.1 Does CI have a code-reviewer step?

`/fix-pr-comments` can only fix comments that exist. Something must produce them first, and **not every repo has an automated reviewer wired into CI** — so determine which reviewer is on the hook the moment the PR is open:

```bash
# in the worktree
ls .github/workflows/ 2>/dev/null \
  && grep -rilE 'claude|code[- ]?review|coderabbit|greptile|codex' .github/workflows/
# and what the PR itself reports
gh pr checks <PR_URL> 2>&1 | head -20
```

| Finding | What you do |
|---------|-------------|
| **No `.github/workflows/`, or no workflow/bot that posts code review comments** | **Run `/pr-review <PR_URL>` yourself, right after opening the PR.** It reviews the diff against the ticket and posts tiered comments (🔴 Critical / 🟡 Warning / 🔵 Suggestion), inline where possible — giving Phase 6 something to work from. |
| A CI workflow / bot app *does* post review comments | **Do not run `/pr-review`** — let CI review, so you don't duplicate it. Wait for its comments to land (`gh pr checks <PR_URL> --watch`, then `gh pr view <PR_URL> --comments`) before moving on. |

Paste the detection output into the transcript either way — the goal contract checks for it, and "CI reviewed it" and "nobody reviewed it" are otherwise indistinguishable.

Then continue to Phase 4; `/fix-pr-comments` runs in Phase 6 against whichever set of comments now exists.

---

## Phase 4 — Merge to staging for QA (per repo)

"Merge to staging" means a **direct git merge + push to the staging branch — NOT a PR targeting staging** — unless the profile describes a different staging flow, in which case follow the profile.

1. `git checkout staging && git pull origin staging`, merge the feature branch in, push.
2. Staging is a shared QA branch and **can be force-pushed during deploy-fixes** — after pushing, verify your merge actually survived (re-fetch and confirm your commits are present). If a conflict or clobber occurred, resolve and re-push.
3. Surface the push output in the transcript (the goal contract checks for it).
4. If the profile says how to **confirm the staging deploy** (a deploy-status API, a health endpoint, a version string), check it and surface the result. Only read deploy *status* unless the profile says logs are safe to read.

---

## Phase 5 — Get the pipeline green (per PR)

Poll the PR checks and fix failures until everything is green:

- `gh pr checks <PR> --watch` / `gh run list` / `gh run view <id> --log-failed` to see what failed. If the repo has **no checks at all**, surface that (`gh pr checks` → "no checks reported") and run the profile's local verification commands (typecheck/lint/affected tests) instead.
- Distinguish **real failures** (your code) from **known flakes** listed in the profile or the project's docs. For a known flake, **re-run the job** rather than "fixing" passing code; note it.
- Fix real failures, push, re-check.
- **Cap: after 3 fix attempts on the same failing step**, stop — run `/goal clear` and present the failure to the user with what you've tried.

---

## Phase 6 — Resolve the PR review comments

By now the PR has been reviewed — either by CI's reviewer, or by you via `/pr-review` in 3.1 when the repo has no reviewer step.

1. **If CI owns the review, wait for it to finish posting.** Poll `gh pr view <PR> --json reviews,comments` and `gh api repos/{owner}/{repo}/pulls/{n}/reviews` until the review appears and has completed, and **auto-detect the bot's handle** from the review authors (e.g. an app/bot login containing `claude`).
2. **Confirm comments actually exist** before trying to fix them: `gh pr view <PR_URL> --comments`. **No comments *and* no review having run is a bug, not a pass** — go back to 3.1 and run `/pr-review <PR_URL>` yourself rather than skipping ahead to Phase 7.
3. Run **`/fix-pr-comments <PR_URL> [reviewer-handle]`** to address the comments: firm fixes applied and replied to automatically; for discretionary Suggestions you're not taking, leave a short reasoned reply. Escalate to the user only per the stop-and-ask criteria.
4. Push fixes, merge them into staging again (Phase 4), then loop back through Phase 5 (green) — new commits re-trigger CI.
5. If the user has separately requested changes on the PR, their comments take priority over the automated ones.

---

## Phase 7 — Finalize (hand off for QA + deploy)

1. Run any **finishing steps the profile or project docs require** (e.g. writing the rules the ticket decided into the spec repo as its own PR).
2. Move the ticket to the profile's **hand-off** state. If the tracker has no QA-style state, leave the state as the profile says and rely on the hand-off comment.
3. Post a hand-off comment on the ticket and a summary to the user covering: what was built, key decisions, affected repos + PR links, that changes are **on staging ready to QA**, how to QA it (test accounts or data from the profile, if any), and the pipeline/review status.
4. **Leave the PR open against the default branch. Do NOT merge to main and do NOT deploy** — those require the human's explicit action after QA.
5. Once the hand-off is done and all contract conditions are surfaced, the `/goal` evaluator will clear the goal. Tell the user exactly what's left: **QA on staging, then merge/deploy.**

---

## Never do
- Never merge to `main` (or the default branch) without explicit user approval.
- Never open a PR that targets `staging`.
- Never deploy to production.
- Never run the full test suite when only a subset is affected.
- Never force-push over someone else's work without verifying and flagging it.
- Never hardcode a project's tracker IDs, hostnames or credentials into this skill, and never commit a project profile to a shared repo.
- Never look for credentials anywhere the profile doesn't point to.
