# Project profile template

Copy this to `~/.claude/build-it/projects/<project>.md` on each machine where you run `build-it`, and fill it in. Profiles are **machine-local on purpose**: credential paths and connections differ per machine, and they must never be committed to a shared repo. Keep secrets out of the profile itself; it should only say **where** they are loaded from.

Delete any section that doesn't apply. Anything you leave out, `build-it` works out from the project's `CLAUDE.md` or asks about.

```markdown
# <Project name>

## match
- paths: ~/work/acme            # cwd under any of these selects this profile
- remotes: github.com/acme/     # or a repo's origin URL contains this
- ticket_pattern: ^ACME-\d+$    # or the ticket id matches this

## tracker
- type: linear                  # shortcut | linear | github | jira
- connection: MCP server `linear-acme` if available, else REST
- load: . ~/.config/acme/tracker.env    # exports LINEAR_API_KEY; omit for MCP-only
- workspace / team: Acme, team key ACME (team id ...)
- states: start = In Progress; hand-off = Ready for QA     # names, or pinned ids
- on hand-off with no QA state: leave as In Review and comment
- create defaults: workflow ..., team ...   # only if build-it ever creates tickets

## repos
- app repos: ~/work/acme/apps/api, ~/work/acme/apps/web
- default branch: main (GitHub's default for web is stale; ignore it)
- worktrees: ~/work/acme/worktrees/<branch>, prefix api-/web- when both repos change
- branch: <type>/<ticket-id>/<slug>, types feature|bug|chore; prefer the tracker's generated branch name
- commits: `feat: ... [ACME-123]`; only the implemented ticket's id in commits/PR text

## delivery
- review: no CI reviewer, so run /pr-review
- checks: no CI; verify locally with `bun run typecheck && bun run lint && bun run test <affected>`
- known flakes: ...
- staging: merge feature branch into `staging` and push; auto-deploys
- confirm deploy: ... (status only; logs not safe to read)
- PRs: invoking build-it counts as approval to open the PR; never merge to main

## qa
- staging URL: ...
- test accounts: credentials in ~/.config/acme/qa.env; helper `acme-qa-token mentor|mentee`
- data: `acme-psql "<sql>"` (staging read/write; say what you'll change first; no deletes)
- emails: use the real accounts for anything that sends email, so the human sees it

## finishing
- extra steps before hand-off, e.g. write the rules the ticket decided into the spec repo as its own PR
```
