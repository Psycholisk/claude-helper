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

## Branch Naming Convention

```
[type]/[ticket-id]/[short-name]
```

**Types** (map to the work being done):
- `feature/` — New features
- `bug/` — Bug fixes
- `chore/` — Maintenance, refactoring, tooling, docs

**Examples:**
- `feature/TICKET-123/profile-preview`
- `bug/TICKET-456/email-validation`
- `chore/TICKET-789/upgrade-deps`

> The `[ticket-id]` placeholder works for any tracker (Shortcut `sc-123`, Linear `ENG-42`, Jira `PROJ-7`, GitHub `#123`). If a project has no ticket tracker, the segment can be dropped or replaced with a short topic slug.

**Reference the ticket in commits:**
```
feat: add profile preview component [TICKET-123]
```

---

## Worktree-Based Development

All development happens in **git worktrees**, never directly on `main` in the working checkout.

**CRITICAL — Worktree-first rule:**
- **Create the worktree BEFORE writing any code.** Never make code changes directly in the primary checkout — that directory must always stay clean on `main`.
- All edits, new files, and changes go directly in the worktree directory. Do not edit files in the primary checkout and move them later.
- This prevents conflicts when working on multiple tickets in parallel, since each worktree is an isolated copy.

### Starting a new piece of work

1. Pull `main` in the primary checkout
2. Create a worktree using the branch name:
   ```bash
   git worktree add ../worktrees/<branch-name> -b <branch-name>
   ```
3. Do all development work inside the worktree — never in the primary checkout
4. Update ticket status (e.g., move to "In Progress") if a tracker is in use

### After the PR is merged

1. **Ask the user before creating a PR** — they may want to review the diff or run a review command first
2. Update ticket status to "Done" (if a tracker is in use)
3. Delete the worktree and prune:
   ```bash
   git worktree remove ../worktrees/<branch-name>
   ```
4. Pull `main` in the primary checkout to stay up to date

---

## While Working

- **Always add tests** for any code changes or additions that require tests. Don't ship logic without coverage unless explicitly told to.
- **For medium-to-large decisions, ask the user first** — present options and let them decide. Examples: introducing a new dependency, choosing between two architectural approaches, deviating from existing patterns.
- **Reference the ticket in commits** so history is traceable back to the work item.

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

---

## Default Coding Conventions

> These are sensible defaults for TypeScript/JavaScript projects. Downstream repos may override them in their own `CLAUDE.md`.

- **Files**: kebab-case (`user-profile.service.ts`)
- **Classes**: PascalCase (`UserProfileService`)
- **Functions/variables**: camelCase (`getUserById`)
- **Constants**: SCREAMING_SNAKE_CASE (`MAX_SESSION_LENGTH`)
- **Database columns**: snake_case (`created_at`)
- **No `any` types** — use `unknown` if needed
- **Explicit return types** on functions
