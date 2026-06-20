---
description: Review a GitHub PR for correctness, security, conventions, tests, and regression risk — then post tiered (Critical/Warning/Suggestion) comments directly on the PR, inline where possible. Reads existing comments and the originating ticket first.
argument-hint: GitHub PR URL or number (required), e.g. https://github.com/org/repo/pull/123 or 123
---

# PR Review

You are reviewing a single GitHub pull request and **publishing the findings as comments on the PR itself** — inline on the relevant line when a finding maps to specific code, or as a general PR comment when it does not. The terminal output is a summary; the PR comments are the deliverable.

## Core Principles

- **A PR argument is required.** This command does nothing useful without one. See Phase 0 — if no PR is given, stop and ask.
- **Context before critique.** Read the PR description and the originating ticket *before* reading the diff. A PR can be bug-free yet still fail to do what the ticket asked — you can't judge that without the intent.
- **Never repeat existing feedback.** Read all existing PR comments (inline + general) and prior reviews first. Silently drop any finding a human or a previous run already raised. A review bot that re-posts known issues is noise.
- **Every finding is tiered** into exactly one of:
  - 🔴 **Critical** — must fix before merge (bugs, security holes, broken/changed existing behavior, data loss).
  - 🟡 **Warning** — should fix (likely problems, missing tests on risky paths, convention violations that hurt maintainability).
  - 🔵 **Suggestion** — nice to have (style, minor cleanups, optional improvements).
- **Regression risk is a first-class lens.** "Does this unintentionally change existing behavior?" is reviewed as deliberately as "is this code correct?". Trace the callers, not just the diff.
- **Actionable, specific, no padding.** Each comment says what's wrong, why it matters, and a concrete fix. No praise filler, no restating the code.
- **Posting to a PR is outward-facing** — confirm the finding tally with the user once before publishing.
- **Use TodoWrite** to track the phases.

---

## Phase 0: Validate the Argument

Initial input: $ARGUMENTS

- If `$ARGUMENTS` is empty or contains no PR URL/number, **STOP**. Tell the user:
  > "This command requires a PR link or number, e.g. `/pr-review https://github.com/org/repo/pull/123` or `/pr-review 123`."
  Do not review anything.
- Otherwise extract the PR reference. Accept a full URL (`https://github.com/<owner>/<repo>/pull/<n>`) or a bare number (`123`, resolved against the current repo).

---

## Phase 1: Resolve the PR

Use the GitHub CLI (`gh`). It accepts a URL or a number as the PR reference (call it `$PR`).

```bash
gh pr view "$PR" --json number,title,body,url,headRefName,baseRefName,headRefOid,author,files,additions,deletions,state
gh repo view --json owner,name   # or parse owner/repo from the URL
```

Capture: `number`, `headRefOid` (head commit SHA — required to anchor inline comments), `baseRefName`, `headRefName`, `owner`, `repo`.

---

## Phase 2: Gather Context (before reading the diff)

1. **PR description** — read the `body`. What is this PR *supposed* to do?
2. **Existing feedback** — fetch everything so you never repeat it:
   ```bash
   gh api "repos/<owner>/<repo>/pulls/<number>/comments" --paginate   # inline review comments
   gh api "repos/<owner>/<repo>/issues/<number>/comments" --paginate  # PR-level comments
   gh pr view "$PR" --json reviews                                    # prior review summaries
   ```
   Build a list of already-raised issues. Any finding overlapping one of these → **drop it**.
3. **Originating ticket** — discover the work source from the branch name and PR body, then read it for acceptance criteria and intent:
   - **Shortcut** (`feature/sc-123/...`, `sc-123`, `[sc-123]`): fetch via API if `$SHORTCUT_API_TOKEN` is set, or a Shortcut MCP if available:
     ```bash
     curl -s -H "Shortcut-Token: $SHORTCUT_API_TOKEN" "https://api.app.shortcut.com/api/v3/stories/123"
     ```
   - **GitHub issue** (`Closes #45`, `Fixes #45`, `#45`): `gh issue view 45 --json title,body`.
   - **Jira / Linear / Trello / other**: if a URL or ID is present and you have access (MCP/CLI/`WebFetch`), fetch it; otherwise note the ticket couldn't be read and proceed.
   - **No ticket reference**: use the PR description as the sole source of intent.

---

## Phase 3: Read the Diff and Surrounding Code

```bash
gh pr diff "$PR"
```

For each changed file, also read the surrounding code and the key callers of changed functions. The diff alone is insufficient to judge regression risk.

---

## Phase 4: Review Across Five Lenses

For every hunk, evaluate:

1. **Correctness & bugs** — logic errors, edge cases, null/undefined, off-by-one, race conditions, error handling, wrong assumptions.
2. **Security** — injection, auth/authz gaps, secrets in code, unsafe input handling, sensitive-data exposure, unvalidated external input.
3. **Conventions & quality** — naming, structure, dead code, duplication, and adherence to the repo's own `CLAUDE.md`/lint conventions if present (read it). Was touched code left at least as clean as it was found?
4. **Tests** — are new/changed paths covered? Are risky branches tested? Are the tests meaningful, not just present?
5. **Regression risk — unintended behavior change**:
   - Trace callers of every modified function/signature — do they still behave correctly?
   - Did a default, return shape, or side effect change in a way existing callers don't expect?
   - Were shared utilities, configs, or types altered beyond the PR's stated scope?
   - Flag anything that silently alters behavior the PR didn't intend to change.

Assign each finding a tier. Where it maps to a specific line, record `path` + `line` + `side` (`RIGHT` for added/context lines, `LEFT` for removed).

---

## Phase 5: Confirm Before Posting

Posting to a live PR is outward-facing and not cleanly reversible. Present the tally and confirm once:

> "Reviewed PR #<n> «<title>». Found **N Critical, M Warning, K Suggestion** (after dropping D already-raised). Post these to the PR?"

Offer: **Post all** / **Post Critical + Warning only** / **Don't post (show me here)**. If the user declines, print the findings in the terminal and stop.

---

## Phase 6: Post the Review

Post all inline comments and the summary in a **single review API call**. Choose the review `event` from the findings being posted:

- **≥1 Critical posted → `"REQUEST_CHANGES"`** — Criticals block the merge.
- **No Critical posted → `"COMMENT"`** — advisory only.
- Never use `"APPROVE"`.

Build the payload, then submit:

```json
// review.json — event is REQUEST_CHANGES when any Critical is posted, else COMMENT
{
  "commit_id": "<headRefOid>",
  "event": "REQUEST_CHANGES",
  "body": "## 🔍 Automated review\n\n**Summary:** <1–2 sentences on overall state vs. ticket intent>\n\n**Tally:** 🔴 N Critical · 🟡 M Warning · 🔵 K Suggestion\n\n<Findings NOT tied to a specific line go here as a tiered bullet list.>",
  "comments": [
    { "path": "src/foo.ts", "line": 42, "side": "RIGHT", "body": "🔴 **Critical:** <issue>. <why it matters>. <suggested fix>." },
    { "path": "src/bar.ts", "line": 88, "side": "RIGHT", "body": "🟡 **Warning:** <issue>." }
  ]
}
```

```bash
gh api "repos/<owner>/<repo>/pulls/<number>/reviews" --method POST --input review.json
```

Rules:
- `event` is `REQUEST_CHANGES` when at least one Critical is in the posted set, otherwise `COMMENT`. Never auto-approve.
- Each inline comment body starts with its tier badge: `🔴 **Critical:**`, `🟡 **Warning:**`, `🔵 **Suggestion:**`.
- Line-specific findings → `comments[]`. Non-line findings (architecture, overall missing tests, ticket-scope gaps) → the review `body`.
- If the API rejects a `comments[]` entry because the line isn't in the diff, move that finding into the review `body` and retry — don't drop it.

---

## Phase 7: Report

Print a short terminal confirmation: PR URL, the tally posted, duplicates skipped, and a link to the submitted review. Mark todos complete.

---

## What this command will not do

- Run without a PR argument
- Re-post findings already raised by a human or a prior review
- Auto-approve a PR (it will Request Changes when Criticals exist, but never Approve)
- Review the diff blind to the PR description and originating ticket
- Post to the PR without confirming the tally first
- Pad comments with praise or restate what the code obviously does
