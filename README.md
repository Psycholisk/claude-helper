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

Skills are richer, multi-file capabilities that Claude loads automatically when a task matches (or you can invoke explicitly as `/skill-name`).

| Skill | Description |
|-------|-------------|
| `qa-buddy` | Run a structured QA pass on a block of work — a Shortcut ticket, GitHub PR, or local branch/diff. Analyzes what changed, builds a test plan tied to acceptance criteria, runs a guided verification (🤖 Claude-verifiable vs 🧑 human-required), and posts a ship/no-ship report back to the ticket or PR |
| `build-it` | End-to-end autonomous delivery of a Shortcut ticket. Composes the native `/goal` loop with `/feature-dev` (implement) and `/fix-pr-comments` (resolve review comments): implements the ticket, opens a PR against the default branch, merges to staging for QA, drives the pipeline green, and resolves the automated Claude review — leaving the human only QA + deploy. Runs solo, stopping only for critical/architectural decisions |

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
```

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

1. Create a directory in `skills/` named after the skill (e.g. `skills/qa-buddy/`)
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
- [GitHub CLI](https://cli.github.com/) (`gh`) — required by `/fix-pr-comments`
