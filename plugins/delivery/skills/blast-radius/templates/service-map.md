# Service map: who a repo's changes reach

A starting point for turning "files changed in repo X" into "people affected". It's a hint,
not ground truth: when a repo matters to the report, skim its `CLAUDE.md` / `AGENTS.md` /
`README.md` and the changed code to confirm. Add a row, or fix one, whenever a report teaches
you something new. The rows below are examples to replace.

## Audiences

Split external users the way your business does. A change can be invisible to one group and
very visible to another.

| Audience | Who they are | Typical touchpoints |
|---|---|---|
| **Clients** | Businesses or users who pay you | Web dashboard, public API / integrations, outbound webhooks, invoices, transactional emails |
| **End users** | Your clients' customers, if you have them | Public pages, notifications (email / SMS / WhatsApp), self-service flows |
| **Ops** | Internal operations | Admin tools, internal alerts |
| **Support** | Customer support agents | Helpdesk, order / account history, whatever they explain to clients |
| **Finance** | Billing, collections | Billing service, accounting system, payment provider |
| **Sales / Account managers** | Client-facing commercial team | CRM, onboarding flows |

## Repos

| Repo | What it is | Who it reaches | Deploy / risk quirks |
|---|---|---|---|
| `web-dashboard` | Client dashboard and internal admin actions | Clients, Ops, Support | Admin-only vs client-visible matters for the impact split. |
| `public-tracking` | Public status page | End users | Example quirk: default branch is `develop`; prod needs a release tag, so merged ≠ live. |
| `core-api` | Core orders / accounts API | Everyone downstream | Example quirk: migrations are NOT run on deploy; someone runs them by hand. |
| `billing` | Invoices, payments, accounting sync | Finance, Clients | Example quirk: staging is fed by cherry-picks, so check staging separately. |
| `webhooks` | Outbound webhooks | Clients' systems | A contract change can break client integrations silently. |

## Manual deploy steps

Steps a merge doesn't do by itself. `/delivery:ship-it` lists them as ✋ manual steps.

| Repo | Step | How |
|---|---|---|
| `core-api` | Run migrations | `<command>` |

## Shared data and its hidden readers

Tables whose values reach people through paths a PR rarely mentions. When a change writes to
one of these, check the readers listed here (and grep for more).

| Table / data | Readers that surface it |
|---|---|
| `<service>.<table>.<column>` | `<screen / endpoint / email / report>` |

## Off-repo touchpoints that changes often reach

- **Automations** (n8n, Zapier, workflow engines): read-only. Never run a workflow to "check".
- **CRM fields** (Salesforce, HubSpot…): Sales see them directly.
- **Accounting / payments**: API limits and real money apply.
- **Chat alerts and digests**: a changed message shape is an internal touchpoint change.
- **Warehouse / BI** (BigQuery, dbt, dashboards): a renamed column or new status value can break
  a report nobody on the PR thought of.
