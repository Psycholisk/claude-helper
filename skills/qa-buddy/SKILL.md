---
name: qa-buddy
description: This skill should be used when the user asks to "QA this", "QA this ticket/PR", "create a QA plan", "test this work", "verify this change", or wants a structured quality-assurance pass on a block of work identified by a Shortcut ticket (sc-XXXX), a GitHub PR, or a local branch/diff. It analyzes what changed, produces a test plan, runs a guided verification, and reports results.
version: 0.1.0
---

# QA a Block of Work

Guide a quality-assurance pass on a discrete block of work. The work is identified by **one or more** of: a Shortcut ticket (`sc-XXXX`), a GitHub PR (number or URL), or a local branch/diff. The skill runs in five phases: **Identify → Understand → Plan → Run → Report**.

The goal is a confident ship/no-ship recommendation backed by evidence — not a generic checklist. Tie every test scenario to either an acceptance criterion or a concrete risk visible in the diff.

## Phase 1 — Identify the work

Figure out what is being QA'd. Accept any combination of inputs and cross-link them:

- **Shortcut ticket** (`sc-XXXX`, or a Shortcut URL): use the Shortcut MCP (`mcp__shortcut__stories-get-by-id`) to pull the title, description, **acceptance criteria**, tasks, and comments. Check the ticket's external links for an associated PR.
- **GitHub PR** (number, URL, or "the open PR on this branch"): use `gh pr view <n> --json title,body,commits,files,baseRefName,headRefName` and `gh pr diff <n>`. Scan the PR body for a linked `sc-XXXX`.
- **Local branch / uncommitted diff** (before a PR exists): use `git diff <base>...HEAD` (base is the repo's default integration branch — usually `main`, sometimes `develop`; confirm with `git remote show origin | grep "HEAD branch"`) and `git status` / `git diff` for uncommitted work.

If the user only gave a ticket, try to find the PR (and vice versa) so plan coverage can be matched against real code. If you can't find one side, proceed with what you have and say so.

**Extract and restate** the acceptance criteria (or, if none exist, infer the intended behavior from the description + diff and state your inferred criteria for the user to confirm). These criteria are the backbone of the plan.

## Phase 2 — Understand the change

Read the diff to understand *behavior*, not just file edits. Build a mental model of:

- **User-facing changes** — endpoints, UI flows, CLI, outputs that a tester can observe.
- **Data & contracts** — DB migrations, schema changes, API request/response shapes, event/message schemas.
- **Gates & config** — feature flags, settings rows, env vars, role/permission checks that turn the behavior on or off. *Test both states (gated off and on).*
- **Blast radius** — what existing behavior shares the changed code paths and could regress.

### Quiqup context (apply when relevant)
- **Gates are often dual**: a feature flag **and** a settings table row (e.g. `ReturnSettings.Enabled`). Verify behavior with each gate independently off/on.
- **Backward compatibility**: new Avro/avsc fields need null-first unions + `default:null` or prod syncs drop records; DB migrations must be safe to roll forward on staging.
- **Eventual consistency**: some writes (e.g. BusinessAccount) flow through Salesforce → CDC → Kafka; "it's not there yet" may be lag, not a bug.
- **Tests**: run **only the affected/touched tests**, never the full suite (unless the user asks). Match the repo's runner (Go/Encore `go test ./pkg/...`, `bun test`, etc.).

## Phase 3 — Build the QA plan

Produce a structured plan. Use the template in `report-template.md` as the shape. For each scenario include: **precondition → steps → expected result**, and tag it with the acceptance criterion or risk it covers.

Cover, at minimum:
1. **Acceptance-criteria coverage** — one scenario per criterion. Every criterion must map to a test.
2. **Happy path** — the primary intended flow.
3. **Edge cases** — boundaries, empty/null inputs, large inputs, concurrent actions.
4. **Error paths** — invalid input, auth failures, downstream errors; assert graceful handling.
5. **Gate matrix** — behavior with each flag/setting off and on.
6. **Regression risk** — the existing behaviors in the blast radius from Phase 2.

Then **split each scenario** into:
- **🤖 Claude-verifiable** — runnable tests, builds, linters, hitting endpoints, querying the DB, checking logs.
- **🧑 Human-required** — UI/visual checks, prod-like data, third-party integrations, anything Claude can't observe.

Present the plan to the user before running. Let them trim or add scenarios.

## Phase 4 — Guided run

Work through the plan, tracking pass/fail/blocked per scenario.

**For 🤖 Claude-verifiable scenarios** — execute and capture evidence:
- Run affected tests; run build & lint for the touched area.
- Hit endpoints (curl/httpie) and assert responses.
- Query the DB or check state where possible.
- Logs: **non-local** via `logcli` with the `LOKI_*` env vars (quiqup-platform streams key on `namespace`, not `service_name`); **live pod** via `kubectl logs -f`.
- Record the actual command and its output as evidence.

**For 🧑 Human-required scenarios** — present each as a clear, numbered instruction ("Open X, do Y, you should see Z"). Collect the user's result before moving on. Don't mark a human scenario passed without confirmation.

Mark anything you couldn't verify as **blocked**, with the reason. Never report a guess as a pass.

## Phase 5 — Report

Summarize using `report-template.md`:
- **Coverage** — each acceptance criterion → covered / not covered, with result.
- **Results** — pass / fail / blocked per scenario, with evidence (commands, outputs, screenshots-needed).
- **Issues found** — concrete, reproducible, with severity.
- **Residual risk** — what wasn't or couldn't be tested.
- **Recommendation** — ✅ ship / ⚠️ ship with follow-ups / ❌ fix first, with the reasoning.

First **present the report in chat**. Then **ask the user whether to post it back** — don't post autonomously. QA often runs in multiple rounds (test → fix → re-test), so the first report may not be final, and the user decides when it's worth posting.

When the user says yes, post to **one** target in priority order: Shortcut ticket, else PR (else there's nowhere to post — leave it in chat).

**Update the prior QA report instead of duplicating it** across rounds:
- Begin every posted report with a stable marker as its first line — `<!-- qa-buddy-report -->` — followed by a `## 🧪 QA Report — Round N` heading.
- **GitHub PR**: list existing comments (`gh pr view <n> --json comments`, or `gh api /repos/{owner}/{repo}/issues/{n}/comments`) and look for the marker. If found, edit that comment in place (`gh api -X PATCH /repos/{owner}/{repo}/issues/comments/{id} -f body=@file`); otherwise create one with `gh pr comment`. Bump the round number and keep a short trail of prior rounds (collapsed/summarized) so history isn't lost.
- **Shortcut**: scan the story's comments for the marker. The MCP can create comments (`mcp__shortcut__stories-create-comment`) but may not support editing — if there's no edit tool, post a **new** "QA Report — Round N" comment that references the previous round, rather than silently overriding it. Don't leave several conflicting full reports; make it clear which is current.

Always tell the user where you posted (it's outward-facing).

## Notes
- This skill **does not fix bugs** — it finds and reports them. If the user wants fixes, that's a separate step (and per their workflow, in a git worktree, never on `main`).
- Scale effort to the change: a one-line fix needs a short plan; a feature epic needs the full matrix.
- If acceptance criteria are missing and behavior is ambiguous, ask the user rather than inventing intent.
