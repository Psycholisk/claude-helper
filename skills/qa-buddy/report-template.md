# QA Report Template

Use this shape for both the **plan** (Phase 3) and the **report** (Phase 5). Drop sections that don't apply; don't pad.

---

## QA: <ticket / PR / branch> — <short title>

**Source:** sc-XXXX · PR #NN · branch `<name>`
**Base:** `main` (or `develop`)
**Scope:** <one-line description of what changed>

### Acceptance criteria
| # | Criterion | Covered by | Result |
|---|-----------|-----------|--------|
| 1 | <criterion text> | Scenario 1, 3 | ✅ / ❌ / ⏳ blocked |
| 2 | … | … | … |

> If the ticket had no criteria, list the **inferred** intended behaviors here and flag that they're inferred.

### Test scenarios

For each scenario:

**Scenario N — <name>**  `🤖 Claude` / `🧑 Human`  · covers: AC#_ / regression
- **Precondition:** <state, data, gate config>
- **Steps:** 1… 2… 3…
- **Expected:** <observable result>
- **Actual:** <result + evidence — command run, output, what was seen>  ← filled during the run
- **Result:** ✅ pass / ❌ fail / ⏳ blocked (<reason>)

### Gate matrix (if behavior is flag/setting-gated)
| Flag / setting | Off | On |
|----------------|-----|----|
| `<feature_flag>` | <expected behavior> | <expected behavior> |
| `Settings.Enabled` | … | … |

### Issues found
| # | Severity | Summary | Repro / evidence |
|---|----------|---------|------------------|
| 1 | high/med/low | … | … |

### Residual risk
- <what wasn't tested and why — environment, data, time>

### Recommendation
**✅ Ship** / **⚠️ Ship with follow-ups** / **❌ Fix first**

<one paragraph of reasoning tied to the results above>
