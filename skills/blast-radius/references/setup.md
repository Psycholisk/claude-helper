# Delivery skills: setup and tailoring

`/blast-radius`, `/qa-it` and `/ship-it` share one config folder:
`~/.claude/delivery-skills/` (or `$DELIVERY_SKILLS_HOME`). It sits outside the skills, so
updating the skills never overwrites what you've filled in. The skills themselves stay
generic. Everything about *your* team lives in the folder below.

| File | What it holds | Template | Used by |
|---|---|---|---|
| `config.env` | Tracker, GitHub org, code layout, deploy signals, timezone, chat tool, todo app | `blast-radius/templates/config.env` | all three skills and their scripts |
| `service-map.md` | Your repos, who each one reaches, deploy quirks, hidden data readers | `blast-radius/templates/service-map.md` | blast-radius, ship-it |
| `channels.md` | Where each audience hears about a change (channel / person + ID) | `ship-it/templates/channels.md` | ship-it |
| `capabilities.md` | What QA and monitoring can reach (logs, clusters, DBs, test accounts) and the gaps still open | `qa-it/templates/capabilities.md` | qa-it, ship-it watch mode |
| `qa-it.env` | Secrets for QA (tokens, test-account passwords). `chmod 600`, never committed | none | qa-it |

## First run (onboarding)

Run this at the start of any of the three skills, before anything else:

```bash
D="${DELIVERY_SKILLS_HOME:-$HOME/.claude/delivery-skills}"; ls "$D" 2>/dev/null; grep -n '"<' "$D/config.env" 2>/dev/null
```

- **Folder or file missing:** create the folder and copy in the templates the current skill uses
  (always `config.env`). Tell the user in one line that this is the first-run setup.
- **Placeholders left** (`"<...>"` values) **that this run needs:** ask for all of them in **one**
  message, with the template's hint as the example. Fill in what you can work out yourself first
  and only ask to confirm it:
  - `GH_ORG`: from `git remote get-url origin` in the current repo.
  - `CODE_ROOT` / `REPO_GLOBS`: from where the current repo sits.
  - `TRACKER` / `TICKET_PREFIX`: from the connected MCP servers and the branch names.
  - `TIMEZONE`: from `date +%Z`.
  - Deploy signals: from `git log origin/main --format=%s -20` (look for bump commits) and
    `gh api repos/<org>/<repo>/deployments`.
- Write the answers back into the file. Never ask again for a value that is already filled.
- Don't block on values this run doesn't need. For example, `TODO_APP` only matters at ship-it's
  monitoring step.

`service-map.md`, `channels.md` and `capabilities.md` start nearly empty, and that's fine. They
fill up as the skills run: every time the user confirms a channel, a repo quirk or a way to
reach a system, add a row. A run in month three should ask far less than the first one.

## Tailoring: what to optimise for your team

The generic skills work out of the box, but they get much sharper once the files above describe
your setup. These are the changes that paid off most in a real team:

- **Service map with deploy quirks.** List each repo, who it reaches, and the traps
  ("migrations are not run on deploy", "release needs a tag", "deploy aborts on a missing
  secret"). These turn into regression points and manual rollout steps automatically.
- **Hidden data readers.** When a report finds that a table feeds a screen, email or report the
  PR never mentioned, add it to the service map. Those are the findings people miss.
- **Deploy signals.** Set `BUMP_PATH` / `BUMP_PREFIX` if your CI writes GitOps bump commits, so
  "is it live?" is answered from git instead of guessed.
- **Channels with IDs.** Record channel IDs in `channels.md`, plus cross-team channels for
  changes that hit several teams, so drafts go to the right place without a search each time.
- **Ticket workflow state IDs.** Note the "done" state's ID in `config.env` next to its name, so
  ship-it doesn't look it up every run.
- **QA capability recipes.** The biggest win for qa-it is `capabilities.md`: write down exactly
  how to query each staging DB, read each log source, and sign in as each test user. Each recipe
  turns a 🔑 "needs" item into a 🤖 "can do" item for every later run.
- **Long-lived test credentials.** Push for dedicated staging test accounts and long-lived
  tokens (in `qa-it.env`) instead of pasting short-lived sessions.
- **Logs and monitoring.** Put your log query command (Loki/logcli, Datadog, CloudWatch…),
  cluster contexts and error tracker in `capabilities.md`. ship-it's watch mode runs those.
- **Fixed wording.** If your team says "client" instead of "merchant", or has its own risk
  scale, edit the templates in `references/`. They're meant to be adapted.
