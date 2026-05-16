# Project Guidelines for Claude Code

A baseline set of guidelines for Claude Code when working in this repository. These rules are intentionally generic — they should apply just as well to other projects, and this file can serve as a starting template when bootstrapping a new repo's `CLAUDE.md`.

---

## Git Workflow Rules

**CRITICAL — Always follow these rules:**

1. **Always pull from `main`** — When starting new work, always pull from the `main` branch
2. **Always branch from `main`** — Create new branches from `main`, not from feature branches
3. **Always target PRs to `main`** — When creating pull requests, always target the `main` branch unless explicitly told otherwise
4. **Never push directly to `main`** — All changes go through a pull request, even small ones

---

## Code Quality Principles

### Boy Scout Rule

**Always leave code better than you found it.** When touching code that can be improved — unclear naming, dead code, awkward structure — improve it as part of the change.

**Guardrails:**
- Only improve code in the area you're already changing. Do not wander outside the scope of the task to clean up unrelated code.
- Do not re-churn the same code on each iteration. If you improved it last time, leave it alone this time unless there's a new concrete reason to touch it.
- The bar is "noticeably clearer or safer," not "stylistically different." If the change is just preference, skip it.

### Be Nice to Future-You (Comments)

**Leave comments on functions or crucial parts of the code** so that when revisiting the code later, the context and scope are clear.

**Guardrails:**
- Do not comment every line or every function. Most code is self-explanatory from good naming and structure.
- Comment-worthy: non-obvious *why* (hidden constraints, subtle invariants, workarounds for specific bugs, surprising behavior, or the scope/contract of an important function).
- Not comment-worthy: restating *what* the code does, narrating obvious flow, or noting which caller uses it.
