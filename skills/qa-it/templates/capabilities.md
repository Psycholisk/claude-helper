# QA capabilities registry

What qa-it (and ship-it's watch mode) can reach without asking, and the gaps still open.
**Read this before planning. Update it at the end of every run.** It's how each run covers more
than the last. The rows below are examples to replace with your own.

Rules:
- Never write a secret value here, only *where* it lives (an env file, a cluster secret, a
  password-manager item) and how to load it.
- Secrets the user hands over in chat go into `~/.claude/delivery-skills/qa-it.env`
  (`chmod 600`, `KEY=value` lines). Then record the key name here. Load it with
  `set -a; source ~/.claude/delivery-skills/qa-it.env; set +a`.
- Mark each row ✅ verified (date) or ❔ unverified. Downgrade a row as soon as it stops working.
- Write the **exact** recipe: the command, the flags, the gotcha that cost you an hour. A vague
  row ("we have DB access") doesn't save the next run any time.

## Have

| Capability | How to use | Status |
|---|---|---|
| GitHub (PRs, CI, deploys) | `gh` CLI, org from `config.env` | ❔ |
| Ticket tracker (tickets, AC, comments) | Tracker MCP | ❔ |
| Chat (read/search) | Chat MCP | ❔ |
| Deploy status | `~/.claude/skills/blast-radius/scripts/deploy_status.sh <repo> <pr>` | ❔ |
| Logs (staging + prod) | `<e.g. logcli query '{namespace="staging"} \|= "text"'>`, plus how to load its credentials | ❔ |
| Cluster, staging | `<e.g. kubectl --context <staging-ctx> -n <ns> …>`. Always pass `--context`; never rely on the current one. | ❔ |
| Cluster, prod (read-only for QA) | `<e.g. kubectl --context <prod-ctx> -n <ns> get/logs>` | ❔ |
| Error tracker | `<Sentry / Datadog connector or CLI>` | ❔ |
| Staging DB (read-only) | `<connection recipe; credentials in qa-it.env as KEY_NAMES>` | ❔ |
| Staging API as a client | `<token key in qa-it.env, how to get a fresh one, when it expires>` | ❔ |
| Browser automation | `<Playwright / your e2e skill; how to sign in headlessly>` | ❔ |

## Gaps (push to close these)

| Gap | What it blocks | How to close it for good |
|---|---|---|
| Staging client login (long-lived) | UI checks without a human driving the browser | A dedicated staging test client with password creds in `qa-it.env`, so Playwright can sign in |
| Staging admin login | Admin-action checks | A staging admin test user; creds in `qa-it.env` |
| Feature-flag control | Gate matrix (flag on/off per account) | Authenticate the flag tool's connector, or a staging API key in `qa-it.env` |
