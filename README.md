# claude-helper

A collection of custom slash commands for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Commands

| Command | Description |
|---------|-------------|
| `/refresher` | Summarize the current session context — what was discussed, last task worked on, and any pending user input |
| `/fix-pr-comments` | Methodically address PR review comments — fetches comments via `gh` CLI, categorizes them, makes fixes, and posts replies |
| `/bug-fix` | Guided bug fixing with reproduction-first repro, root-cause analysis, mandatory regression tests, and a structured PR. Accepts a Shortcut link/ID, Sentry link, or free-form bug description |
| `/pr-review` | Review a GitHub PR for correctness, security, conventions, tests, and regression risk, then post tiered (Critical/Warning/Suggestion) comments on the PR — inline where possible. Reads existing comments and the originating ticket first. Requires a PR link/number |

## Installation

```bash
git clone https://github.com/Psycholisk/claude-helper.git
cd claude-helper
bash install.sh
```

This creates symlinks from the repo's `commands/` directory into `~/.claude/commands/`, so commands stay in sync when you `git pull`.

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

## How It Works

Claude Code loads custom slash commands from `~/.claude/commands/`. Each `.md` file becomes a `/command-name` based on its filename. The markdown content is injected as a prompt when the command is invoked.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [GitHub CLI](https://cli.github.com/) (`gh`) — required by `/fix-pr-comments`
