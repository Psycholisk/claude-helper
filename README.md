# claude-helper

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin marketplace with two plugins:

| Plugin | What's in it |
|---|---|
| `delivery` | The ticket-to-production chain: `build-it` → `qa-it` → `ship-it`, with `blast-radius` underneath. Generic, with a setup that asks for your tracker, repos, deploy signals and channels |
| `helpers` | Everyday commands (`bug-fix`, `pr-review`, `fix-pr-comments`, `refresher`) and output-style skills (`adhd`, `shorten`) |

## Installation

In Claude Code:

```
/plugin marketplace add Psycholisk/claude-helper
/plugin install helpers@claude-helper
/plugin install delivery@claude-helper
```

Or from a shell: `claude plugin marketplace add Psycholisk/claude-helper`, then `claude plugin install delivery@claude-helper`.

Updates: `/plugin marketplace update claude-helper`. The plugins carry no pinned version, so every new commit on `main` counts as an update.

Plugin commands and skills are namespaced: `/helpers:shorten`, `/delivery:ship-it`, and so on.

## `delivery` plugin

| Skill | Description |
|-------|-------------|
| `/delivery:build-it` | End-to-end autonomous delivery of a Shortcut ticket. Composes the native `/goal` loop with `/feature-dev:feature-dev` (implement), `/helpers:pr-review` (review the PR when CI has no code-reviewer step) and `/helpers:fix-pr-comments` (resolve review comments): implements the ticket, opens a PR against the default branch, merges to staging for QA, drives the pipeline green, and resolves the review comments, leaving the human only QA + deploy. Needs the `helpers` plugin and the official `feature-dev` plugin |
| `/delivery:blast-radius` | Impact report for a whole change (often several PRs across repos): plain-English summary, client / end-user / internal-team impact, services and contracts touched, gates and rollout, regression points, post-deploy watch, who to notify, and per-PR staging/prod deploy status. Optionally posts one report per ticket |
| `/delivery:qa-it` | QA one or more tickets end to end: a QA plan from the acceptance criteria and regression risks, one up-front ask for missing access, an autonomous run with evidence (or `-i` to walk through it), and a fixed QA checklist report. Keeps a capabilities registry so each run covers more |
| `/delivery:ship-it` | Post-merge close-out: waits until the PRs are live, cleans up worktrees and branches, posts a blast-radius report on each ticket, moves tickets to done, drafts team / deploy-watch / shipped messages for approval, proposes todo-app monitoring tasks, and has a `watch` mode for daily post-deploy checks |

### Setup

The skills are generic: nothing about a specific company is baked in. Your team's details come from two places.

**1. Plugin options.** These are asked when you enable the plugin, and you can change them any time in `/config`:
- tracker and ticket prefix
- done state
- GitHub org, code folder and repo layout
- production and staging branches, and GitOps bump path
- timezone
- your name, chat tool and chat user ID
- todo app and project

**2. A config folder, `~/.claude/delivery-skills/`.** It sits outside the plugin, so updates never overwrite it and it survives an uninstall. A SessionStart hook creates it from templates the first time.

| File | Holds |
|---|---|
| `config.env` | Fallback for the options, plus advanced keys such as bump-commit prefix, deploy env names, slow repos, working days and check time |
| `service-map.md` | Your repos, who each reaches, manual deploy steps, deploy quirks, hidden data readers |
| `channels.md` | Which channel or person each audience hears from |
| `capabilities.md` | What QA and monitoring can reach (logs, clusters, DBs, test accounts) and the open gaps |
| `qa-it.env` | QA secrets (`chmod 600`) |

Anything still missing is asked for the first time a skill needs it, all in one message, and never asked again.

**Tailoring is where they get good.** The generic versions work out of the box, but they get much sharper as those files fill in. The biggest wins are:
- deploy quirks per repo;
- exact log, DB and test-account recipes for QA;
- channel IDs.

See `plugins/delivery/skills/blast-radius/references/setup.md` for the full list.

## `helpers` plugin

| Command / skill | Description |
|---------|-------------|
| `/helpers:refresher` | Summarize the current session context: what was discussed, the last task worked on, and any pending user input |
| `/helpers:fix-pr-comments` | Methodically address PR review comments: fetches comments via `gh` CLI, categorizes them, makes fixes, and posts replies |
| `/helpers:bug-fix` | Guided bug fixing with reproduction-first repro, root-cause analysis, mandatory regression tests, and a structured PR. Accepts a Shortcut link/ID, Sentry link, or free-form bug description |
| `/helpers:pr-review` | Review a GitHub PR for correctness, security, conventions, tests, and regression risk, then post tiered (Critical/Warning/Suggestion) comments on the PR, inline where possible. Reads existing comments and the originating ticket first. Requires a PR link/number |
| `/helpers:adhd` | Shape output for a reader with ADHD: lead with the next action, number multi-step work, restate where you are, suppress tangents, give concrete time estimates, make finished work visible. `/helpers:adhd <prompt>` answers that prompt in this style; bare `/helpers:adhd` reshapes the previous response without redoing any work |
| `/helpers:shorten` | Strip output down to the straight answer. Bare `/helpers:shorten` condenses the previous response without redoing work, `/helpers:shorten <prompt>` answers tersely, `-s` toggles terse mode for the whole session, `-en` layers plain-English phrasing (no code, no jargon) on top |

Usage:

```
/helpers:refresher
/helpers:fix-pr-comments https://github.com/org/repo/pull/123
/helpers:fix-pr-comments https://github.com/org/repo/pull/123 reviewer-username
/helpers:bug-fix sc-12345
/helpers:bug-fix "users can't checkout when cart has more than 50 items"
/helpers:adhd why is the staging deploy stuck?
/helpers:shorten -s
```

## Repo layout

```
.claude-plugin/marketplace.json      lists the plugins
plugins/
  delivery/
    .claude-plugin/plugin.json       manifest + userConfig (the setup options)
    hooks/                           SessionStart hook: writes options to the config folder
    skills/<name>/SKILL.md           + references/, scripts/, templates/
  helpers/
    .claude-plugin/plugin.json
    commands/<name>.md
    skills/<name>/SKILL.md
```

## Adding to a plugin

- **Command:** add `plugins/<plugin>/commands/<name>.md` with a YAML frontmatter `description`. It becomes `/<plugin>:<name>`.
- **Skill:** add `plugins/<plugin>/skills/<name>/SKILL.md` with frontmatter `name` and `description` (the description controls when Claude loads it), plus any supporting files in the same folder.
- **Paths inside a SKILL.md:** use `${CLAUDE_SKILL_DIR}` (this skill's folder) or `${CLAUDE_PLUGIN_ROOT}` (the plugin's root). Never use `~/.claude/skills/...`. These variables are only substituted in SKILL.md bodies, not in files the skill reads later.
- **Test locally** before pushing:

  ```bash
  claude plugin validate .                    # the marketplace
  claude plugin validate plugins/delivery     # one plugin
  claude --plugin-dir plugins/delivery        # a session with the local copy loaded
  ```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI](https://cli.github.com/) (`gh`), used by the PR commands and the delivery skills
- `jq`, used by the delivery skills' scripts
