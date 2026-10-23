# ship-it output format (always this, nothing else)

Every run prints the same sections, in this order, using these exact layouts. Lists of items
are tables. Details sit under them as headed sections with bullet sub-items. Never switch to
numbered or bulleted checklists, and never invent other layouts. Leave out a section only when
it truly has nothing in it, and say so in one line ("Nothing to clean up").

## Fixed vocabulary

- **Status:**
  - ✅ done
  - ✅ already done
  - ✅ confirmed by <OWNER_NAME>
  - ⏳ waiting
  - ❓ can't tell
  - ✋ manual step
  - ⏭️ skipped
  - 🚫 not needed
  - ❌ failed
- **Draft IDs:** `D1`, `D2`, … · **Follow-up IDs:** `F1`, `F2`, … · **Monitoring task IDs:** `M1`, `M2`, …

## 1. Header

```markdown
# 🚀 ship-it: <ticket> <title> (+ <ticket> <title>)
```

## 2. Live check

```markdown
## Live in production
| Ticket | Repo | PR | Production | Detail |
|---|---|---|---|---|
| ENG-101 | core-api | #1566 | ✅ | bump 2760, 10:12 |
| ENG-101 | core-api | migration | ✋ manual step | run `<migration command>` on a prod pod |
```
When anything is ⏳, ❓ or ✋: print this table, then ask **one** question ("Deployed, or skip?"
for each open row) and stop.

## 3. Cleanup

```markdown
## Cleanup
| Ticket | Worktree / branch | Result |
|---|---|---|
| ENG-101 | worktrees/core-api/fix/eng-101/… | ✅ removed, local + remote branch deleted |
```

## 4. Tickets

```markdown
## Tickets
| Ticket | Blast-radius report | Done |
|---|---|---|
| ENG-101 | ✅ <comment link> | ✅ |
| ENG-102 | ✅ already done | ⏳ held: backfill not run yet |
```

## 5. Drafts (nothing is posted until the user names IDs)

```markdown
## Drafts (say e.g. "post D1, D3")
| ID | Draft | Destination | Status |
|---|---|---|---|
| D1 | Ops heads-up | #ops | draft |
| D2 | Finance + Sales heads-up | #finance-sales | draft |
| D3 | Regression watch | #deployments | draft |
| D4 | Shipped | #shipped | draft |

### D1: Ops heads-up → #ops
```
<message text, exactly as it will be posted>
```
### D2: …
```
After posting, re-print the table with Status = ✅ posted (link).

## 6. Monitoring

```markdown
## Monitoring (create these? yes / no)
| ID | Date (check time, local) | Tickets watched | Task line |
|---|---|---|---|
| M1 | Tue 20 Oct | ENG-101, ENG-102 | `/ship-it watch ENG-101 ENG-102 day 1 of 5` |
```

## 7. Follow-ups

```markdown
## Follow-ups worth a ticket
| ID | Ticket | Follow-up | Why it matters |
|---|---|---|---|
| F1 | ENG-101 | Guard against cancelled-order release | A cancelled order can be sent for collection again |
```
Or a single line: "No follow-ups worth a ticket."

## 8. Goal checklist (always last)

```markdown
## Close-out checklist
| Ticket | Merged | Live | Cleanup | Report | Done |
|---|---|---|---|---|---|
| ENG-101 | ✅ | ✅ confirmed by <OWNER_NAME> | ✅ | ✅ | ✅ |
| ENG-102 | ✅ | ✅ | ✅ already done | ✅ | ⏳ |

**Run-wide:** Drafts ✅ presented · Monitoring ⏳ awaiting yes · Follow-ups ✅ listed
```

## Watch mode report

```markdown
# 🔍 Watch: <ticket> (+ <ticket>), day N of M
**Verdict:** ✅ All good / ⚠️ Needs a look / 🔴 Problem: <one line>

| Ticket | Check | Result | Evidence |
|---|---|---|---|
| ENG-101 | Logs "Could not record hold" | ✅ 0 hits | `<log query> …` |
| ENG-101 | Error-tracker error rate | ⏭️ skipped | Error-tracker connector not authenticated |

### <check needing explanation>
- …
```
On the last day, add a final line: **Recommendation:** stop monitoring / extend by N days, because …
