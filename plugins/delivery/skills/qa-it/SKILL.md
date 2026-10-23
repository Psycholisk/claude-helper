---
name: qa-it
description: QA one or more tickets end to end. Writes a QA plan from the acceptance criteria and the change's regression risks, sorts each item into can-do / needs-something-from-you / human-only / can't-do, asks for all missing access once, then runs every check it can by itself with evidence and ends with a QA checklist report of what was and wasn't QA'd and why. `-i` runs the checks interactively, one at a time, guiding the user through each. It keeps a registry of access and pushes to close gaps permanently, so each run covers more. Sits between /delivery:build-it and /delivery:ship-it. Use for "/delivery:qa-it", "QA this", "QA <ticket>", "test this ticket", "is this ready to ship", "verify the acceptance criteria", "create a QA plan", or "walk me through QA".
---

# qa-it

QA a change properly: plan it, get what's needed up front, run everything that can be run,
and end with a clear checklist of what was QA'd, what wasn't, and why. It sits in the chain
`/delivery:build-it` → **`/delivery:qa-it`** → `/delivery:ship-it`.

## Config

This skill is generic. Your team's setup comes from the plugin's options (`/config`) and
`~/.claude/delivery-skills/`: everything QA can reach in `capabilities.md`, secrets in
`qa-it.env`. Before starting, run `${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/scripts/config_status.sh`
and follow "First run" in `${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/references/setup.md` for
anything missing. If `capabilities.md` doesn't exist yet, copy it from
`${CLAUDE_PLUGIN_ROOT}/skills/qa-it/templates/capabilities.md`.

## Output format

Every output uses the fixed layouts in `references/report-template.md`:
- the plan;
- the "needs from you" list;
- each interactive step;
- the final report.

QA items always appear in **the QA table**: same columns, same item IDs (Q1, Q2, …), same
status symbols. Details go below it as headed sections with bullet sub-items. Don't switch to
numbered or bulleted checklists, or improvise other layouts. The user wants every run to look
the same.

## Input

`/delivery:qa-it [-i] [tickets | PR links | free text]`
- **No tickets:** take the ticket(s) currently being worked on in this session, using
  `/delivery:blast-radius`'s session rules (`${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/SKILL.md`, step 1). That may
  be several tickets.
- **Tickets or PRs:** QA exactly those. A PR resolves to its ticket.
- **`-i`:** interactive. After planning, ask whether to walk through **all** items or only the
  **human** ones, then go one item at a time (see phase 4b).
- **`--retest`:** re-run only the items that failed or were blocked in the latest QA report on
  the ticket.

Several tickets get one plan and one run, with a ticket column so each item stays traceable.

## The standing goal: close gaps

Every item that couldn't be QA'd for lack of access is a gap, and gaps should shrink run by run.
`capabilities.md` lists what you can reach and what's missing. Read it before planning and
update it at the end.

When you ask for something, ask for the **permanent** version: a dedicated staging test
account, a long-lived token stored in `~/.claude/delivery-skills/qa-it.env`, a read-only DB
user, an authenticated connector. A one-off password pasted in chat isn't the goal. When the
user gives you something, store it so it's never asked for again: the env file for secrets,
`capabilities.md` for the fact that it exists and the exact recipe to use it. Never put secret
values in reports, comments or `capabilities.md`.

## Phase 1: understand the change

1. **Tickets:** read each one with the tracker MCP: description, acceptance criteria, comments
   (QA steps are often in a build comment), and linked PRs. Find all the PRs with
   `${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/scripts/find_prs.sh <id>`.
2. **Diff:** read every PR's diff (`gh pr diff`). Trust the diff over the description. Note
   endpoints, screens, jobs, events, tables, flags and settings.
3. **Risks:** take the blast-radius regression points and gates. Use the ticket's blast-radius
   comment if there is one. Otherwise follow `/delivery:blast-radius` steps 2–3 for the regression
   analysis, without posting anything.
4. **Environment:** QA runs on **staging**. Confirm the code under test is actually there with
   `deploy_status.sh <repo> <pr>`. Testing code that isn't deployed proves nothing. If staging
   doesn't have it, stop and say so. On **production**, only read (logs, read-only queries)
   unless the user explicitly says otherwise.

If the ticket has no acceptance criteria, work them out from the ticket and the diff and mark
them **inferred**.

## Phase 2: write the plan

Build the QA list. Use the plan template in `references/report-template.md`.
- **One or more items per acceptance criterion:** the happy path, plus the edge and error
  cases that matter.
- **One item per regression point** that's realistically testable.
- **Gate matrix:** each flag or setting, both off and on. Watch for double gates (a feature
  flag *and* a settings row, for example) and test the combinations that matter.
- Scale it to the change. A one-line fix gets a short list; an epic gets the full matrix.

Sort every item into a category, checking `capabilities.md` first:
- **🤖 Can do:** you can run it now (API calls, DB queries, logs, cluster commands, browser
  automation for UI, the repo's targeted tests).
- **🔑 Needs:** possible once the user provides something specific. Name the exact thing and
  the permanent version of it.
- **🧑 Human only:** needs human judgment or a real device (visual quality, real phone, a
  third party's screen).
- **🚫 Can't:** not testable in any environment we have. Say why.

## Phase 3: one checkpoint, then go

Show the plan.
- **Anything in 🔑 Needs:** ask for everything in **one** list, saying which items each thing
  unlocks and its permanent version. Then wait. When the user answers, store what they give
  (see "The standing goal: close gaps") and move those items to 🤖.
- **Nothing in 🔑 Needs, no `-i`:** don't stop. Go straight to phase 4a.
- **`-i`:** ask "Walk through **all** items, or only the **human** ones?" and go to phase 4b.

## Phase 4a: autonomous run

Run every 🤖 item, using the recipes in `capabilities.md`. For each one, record the exact
command or action and its output as evidence.
- **API:** curl or httpie against staging, with tokens from `qa-it.env`.
- **Data:** DB queries, read-only unless the test itself needs to write.
- **Logs and cluster:** the log tool and cluster contexts listed in `capabilities.md`.
- **UI:** Playwright (or an e2e-testing skill if you have one), with screenshots.
- **Tests:** only the repo's tests for the touched areas, never the full suite.

**Test data:** create what you need on staging, labelled `qa-it <ticket>` wherever there's a
free-text field. Record every ID, and clean up afterwards when that's safe. Never create data
on production.

**On a failure,** keep going with the other items. For the failed one, get a clean repro, then
find the likely cause in the code (`repo:path:line`) and suggest a fix. Don't change code here.
If the user wants a fix, that's a separate step in the ticket's worktree.

When the 🤖 items are done, the 🧑 items stay ⏳ in the QA table. Each one gets a Details entry
with Where / Do / Expect so the user can do it later. With `-i`, walk through them as in 4b.

## Phase 4b: interactive run (`-i`)

Strictly **one item at a time**. Never dump the list.
1. Announce it: **"QA 3/9: <name>"**, with what it proves.
2. **For a 🤖 item:** run it yourself, show the result and evidence, then move on.
3. **For a 🧑 item, or any item the user chose to do:** guide them through it.
   - **Where:** the exact URL, screen or menu path to open.
   - **Do:** each step, down to what to click and what to type.
   - **Expect:** what they should see if it works.
   - **Send back:** "done", what they saw, or a screenshot.

   Then **stop and wait**. Check what they send. If it's a screenshot, look at it and compare it
   with what was expected. Run any background checks that go with the step (logs, DB state,
   webhooks), then give the result.
4. Record ✅ / ❌ / ⏳ for the item, then go to the next one. Never mark a human step passed
   without their confirmation.

"Only the human ones" walks through just the 🧑 items, after running the 🤖 items on your own.

## Phase 5: report

Use the final report template in `references/report-template.md`. The core is the QA checklist
table: every item, its result, its evidence, and why for anything not QA'd. Below it:
- acceptance criteria status;
- failures, with repro and likely cause;
- the human checklist (if not walked through);
- test data created;
- capability gaps, with how to close each for good.

Then:
1. **Update `capabilities.md`.** Add new access to "Have" with its exact recipe, move closed
   gaps out of "Gaps", and add new gaps with their permanent fix.
2. **Offer to post the report on the ticket.** QA often runs in rounds, so ask. Begin the
   comment with a `QA report: round N` heading. If the tracker can't edit comments, a new round
   goes in a new comment that says which round it supersedes. Don't change the ticket's state.
   That's for the user, or `/delivery:ship-it` after merge.

## Tailoring

qa-it improves the most from a detailed `capabilities.md`: exact recipes for each staging DB,
log source, cluster and test account, with the gotchas that cost time. Each recipe turns a 🔑
item into a 🤖 item for every later run. See "Tailoring" in
`${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/references/setup.md`.
