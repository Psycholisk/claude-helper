# claude-helper

A collection of custom slash commands and skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Commands

| Command | Description |
|---------|-------------|
| `/refresher` | Summarize the current session context — what was discussed, last task worked on, and any pending user input |
| `/fix-pr-comments` | Methodically address PR review comments — fetches comments via `gh` CLI, categorizes them, makes fixes, and posts replies |
| `/bug-fix` | Guided bug fixing with reproduction-first repro, root-cause analysis, mandatory regression tests, and a structured PR. Accepts a Shortcut link/ID, Sentry link, or free-form bug description |
| `/pr-review` | Review a GitHub PR for correctness, security, conventions, tests, and regression risk, then post tiered (Critical/Warning/Suggestion) comments on the PR — inline where possible. Reads existing comments and the originating ticket first. Requires a PR link/number |

## Skills

Skills are richer, multi-file capabilities that Claude loads automatically when a task matches (or you can invoke explicitly as `/skill-name`). A skill can opt out of auto-loading with `disable-model-invocation: true` in its frontmatter, making it explicit-invocation only.

| Skill | Description |
|-------|-------------|
| `build-it` | End-to-end autonomous delivery of a Shortcut ticket. Composes the native `/goal` loop with `/feature-dev` (implement), `/pr-review` (review the PR when CI has no code-reviewer step) and `/fix-pr-comments` (resolve review comments): implements the ticket, opens a PR against the default branch, merges to staging for QA, drives the pipeline green, and resolves the review comments — leaving the human only QA + deploy. Runs solo, stopping only for critical/architectural decisions |
| `adhd` | Shape output for a reader with ADHD: lead with the next action, number multi-step work, restate where you are, suppress tangents, give concrete time estimates, make finished work visible. Explicit-invocation only — `/adhd <prompt>` answers that prompt in this style, bare `/adhd` reshapes the previous response without redoing any work |
| `shorten` | Strip output down to the straight answer. Explicit-invocation only — bare `/shorten` condenses the previous response without redoing work, `/shorten <prompt>` answers tersely, `-s` toggles terse mode for the whole session, `-en` layers plain-English phrasing (no code, no jargon) on top |
| `blast-radius` | Impact report for a whole change (often several PRs across repos): plain-English summary, client / end-user / internal-team impact, services and contracts touched, gates and rollout, regression points, post-deploy watch, who to notify, and per-PR staging/prod deploy status. Optionally posts one report per ticket |
| `qa-it` | QA one or more tickets end to end: a QA plan from the acceptance criteria and regression risks, one up-front ask for missing access, an autonomous run with evidence (or `-i` to walk through it), and a fixed QA checklist report. Keeps a capabilities registry so each run covers more |
| `ship-it` | Post-merge close-out: waits until the PRs are live, cleans up worktrees and branches, posts a blast-radius report on each ticket, moves tickets to done, drafts team / deploy-watch / shipped messages for approval, proposes todo-app monitoring tasks, and has a `watch` mode for daily post-deploy checks |

### Delivery skills: `blast-radius`, `qa-it`, `ship-it`

These three work as a chain (`/build-it` → `/qa-it` → `/ship-it`, with `/blast-radius` underneath) and are **generic**: nothing about a specific company is baked in. Your team's details live in one folder outside the repo, `~/.claude/delivery-skills/`, so `git pull` never overwrites them:

| File | Holds |
|---|---|
| `config.env` | Ticket tracker, GitHub org, where your clones live, how deploys are detected (GitOps bump commits or GitHub Deployments), timezone, chat tool, todo app |
| `service-map.md` | Your repos, who each reaches, deploy quirks, hidden data readers |
| `channels.md` | Which channel or person each audience hears from |
| `capabilities.md` | What QA and monitoring can reach (logs, clusters, DBs, test accounts) and the open gaps |
| `qa-it.env` | QA secrets (`chmod 600`) |

**Onboarding is automatic:** the first time any of the three runs, it creates the folder from the templates, works out what it can (org, code root, timezone, deploy signals), and asks for the rest in one message. It only asks for what the current run needs, and never asks again for a value that's filled.

**Tailoring is where they get good.** The generic versions work out of the box, but they get much sharper as those files fill in. The biggest wins are deploy quirks per repo, exact log/DB/test-account recipes for QA, and channel IDs. See `skills/blast-radius/references/setup.md` for the full list.

## Installation

```bash
git clone https://github.com/Psycholisk/claude-helper.git
cd claude-helper
bash install.sh
```

This creates symlinks from the repo's `commands/` directory into `~/.claude/commands/` and from `skills/` into `~/.claude/skills/`, so everything stays in sync when you `git pull`.

## Uninstall

```bash
bash uninstall.sh
```

## Usage

After installing, the commands are available in any Claude Code session:

```
/refresher
/fix-pr-comments https://github.com/org/repo/pull/123
/fix-pr-comments https://github.com/org/repo/pull/123 reviewer-username
/bug-fix sc-12345
/bug-fix https://yourorg.sentry.io/issues/...
/bug-fix "users can't checkout when cart has more than 50 items"
/adhd why is the staging deploy stuck?
/adhd
/shorten why did the invoice fail to sync?
/shorten -en
/shorten -s
```

`/adhd` with nothing after it rewrites the previous response in the ADHD style, using only what is already on screen — it does not re-run tools or redo work. `/shorten` behaves the same way; `/shorten -s` makes terse output sticky for the rest of the session (run it again to turn it off).

## Adding New Commands

1. Create a `.md` file in `commands/`
2. Add a YAML frontmatter block with a `description` field
3. Write the prompt instructions in markdown
4. Run `bash install.sh` to symlink the new command

### Command file format

```markdown
---
description: Short description shown in command list
---

# Command Title

Your prompt instructions here...
```

## Adding New Skills

1. Create a directory in `skills/` named after the skill (e.g. `skills/qa-it/`)
2. Add a `SKILL.md` with YAML frontmatter (`name` + `description`) — the `description` controls when Claude auto-loads the skill
3. Add any supporting files the skill references (templates, scripts) in the same directory
4. Run `bash install.sh` to symlink the new skill

### Skill file format

```markdown
---
name: skill-name
description: When this skill should be used — be specific; this drives auto-loading.
---

# Skill Title

Workflow / instructions here...
```

## How It Works

Claude Code loads custom slash commands from `~/.claude/commands/` (each `.md` file becomes a `/command-name`) and skills from `~/.claude/skills/` (each directory with a `SKILL.md`). Commands are injected as a prompt when invoked; skills are loaded automatically when a task matches their `description`, or on demand via `/skill-name`.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [GitHub CLI](https://cli.github.com/) (`gh`) — required by `/fix-pr-comments` and the delivery skills
- `jq` — required by the delivery skills' scripts
