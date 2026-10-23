# qa-it output format (always this, nothing else)

The user wants the **same layout on every run**. So:
- every list of QA items is **the** QA table below, with the same columns in the same order;
- details go underneath as headed sections with bullet sub-items, keyed by item ID;
- never switch to numbered or bulleted checklists, and never invent other tables.

## Fixed vocabulary

- **Item IDs:** `Q1`, `Q2`, … assigned in the plan. They stay the same through the run, the
  report and any `--retest`. With several tickets, keep one sequence and add a Ticket column.
- **Category:** 🤖 Can do · 🔑 Needs · 🧑 Human · 🚫 Can't
- **Result:**
  - — not run yet
  - ✅ Pass
  - ❌ Fail
  - ⏳ Not QA'd (blocked, or waiting on a human)
  - 🚫 Can't QA

## The QA table

Use this one table everywhere: the plan, the run updates and the final report. In the plan,
Result is `—` and the last column says *how* it will be checked. In the report, the last column
holds the evidence, or *why* the item wasn't QA'd.

```markdown
| ID | Ticket | QA item | Covers | Category | Result | Evidence / why not |
|---|---|---|---|---|---|---|
| Q1 | ENG-101 | Unblock releases held orders | AC1 | 🤖 Can do | ✅ Pass | `curl … → 200 {"released":3}` |
| Q2 | ENG-101 | Partial account event doesn't release orders | Reg #3 | 🔑 Needs | ⏳ Not QA'd | Needs staging message-queue produce access |
| Q3 | ENG-102 | Banner copy readable on mobile | AC4 | 🧑 Human | ⏳ Not QA'd | Visual check, see Q3 below |
```

Leave out the Ticket column when only one ticket is being QA'd. "Covers" is `AC<n>`,
`Reg #<n>` (a blast-radius regression point), or `Gate: <flag> on/off`.

## Plan output (phase 2)

```markdown
# 🧪 QA plan: <ticket> <title> (+ <ticket> …)

**Under test:** <repo#PR, …> · **Environment:** staging, code deployed ✅/❌ · **AC:** from ticket / inferred

<QA table>

## Needs from you
| # | What I need | Unlocks | Permanent fix |
|---|---|---|---|
| N1 | Staging client login | Q4, Q7 | Dedicated test account in `qa-it.env` |

(If nothing is needed: "Nothing needed, starting the run.")
```

## Interactive step (phase 4b), one per message

```markdown
### QA 3/9 · Q3: <name>  (🧑 Human · covers AC4)
- **Proves:** <one line>
- **Where:** <URL / screen / menu path>
- **Do:**
  1. <step>
  2. <step>
- **Expect:** <what you should see>
- **Send back:** "done", what you saw, or a screenshot
```
After the reply: `**Q3 → ✅ Pass**: <evidence>` (or ❌ / ⏳), then the next step block.

## Final report (phase 5)

```markdown
# 🧪 QA report: <ticket> <title>, round N

**Verdict:** ✅ Ready to ship / ⚠️ Ship with follow-ups / ❌ Fix first: <one line why>
**Coverage:** <x>/<n> QA'd · <a> ✅ · <f> ❌ · <b> ⏳ · <c> 🚫

<QA table, every item, final results>

## Details
### Q2: <name> ❌
- **Expected:** …
- **Actual:** …
- **Repro:**
  1. …
- **Likely cause:** `repo:path:line`, <why>
- **Suggested fix:** …
- **Severity:** high / med / low

### Q3: <name> ⏳ (human)
- **Where / Do / Expect:** …

## Acceptance criteria
| AC | Criterion | Items | Status |
|---|---|---|---|

## Test data
| Record | ID | Cleaned up |
|---|---|---|

## Capability gaps
| Gap | Blocked | Permanent fix |
|---|---|---|
```

Only failures, human items and anything that needs explaining get a Details entry. Passed items
stay as table rows. Leave out an empty section entirely rather than showing it empty.

Rules: a result without evidence is not a pass. "Couldn't run" is ⏳ or 🚫, never ✅.
