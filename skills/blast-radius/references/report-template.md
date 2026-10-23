# Blast-radius report template

Fill every section. If a section genuinely has nothing, write one line saying so and why
("No client-visible change — admin-only action behind an admin role") — an empty heading
reads like it was skipped. Keep bullets concrete: name the screen, endpoint, table, event,
flag, chat channel. Cite code as `repo:path:line` where it helps a reviewer verify.

```markdown
# 💥 Blast radius — <change name> (<feature | bug fix | chore | refactor>)

**Ticket(s):** <ticket> <title> (+ <ticket> <title> when combined) · **Risk:** 🟢 Low / 🟡 Medium / 🔴 High — <one-line reason>
**AC:** <all met / which are open or met differently, one line>
**Related, not analysed:** <MENTION PRs, overlapping or epic tickets — or omit>

| Repo | PR | State (CI · review · mergeable) | Staging | Production |
|---|---|---|---|---|
| core-api | #1566 migration | open · ✅ CI · review required · clean | ✅ | ❌ |
| core-api | #1567 code | open · ❌ CI (flake, green on main) · review required · conflicts | ✅ | ❌ |

## What we did
<One short paragraph in plain English — no jargon, no file names. Explain the problem and what
now happens differently, so anyone in the company could read it. E.g. "When a client's account
was blocked for unpaid invoices, their new orders were put on hold — but unblocking them never
released those orders, so Ops had to find and release them by hand. Now, as soon as an account
is unblocked, its held orders are released automatically.">

## External impact
<One line per external audience in the service map, e.g.:>
**Clients:** <what a client sees or experiences differently; or "none">
**End users:** <public pages, notifications, self-service flows; or "none">

## Internal impact
| Team | What changes for them | Touchpoint |
|---|---|---|
| Ops | ... | Admin dashboard → ... |
| Finance | ... | #finance alert |

**Touchpoints changed:** <list: screens, emails, chat messages, CRM fields, automations, reports — or "none">

## Technical changes
<Keep this short: one line per service changed. The detail belongs in the PRs.>
- **<repo>** — <what changed in behaviour, 1–2 lines> (`path/to/key/file`)
- **Interfaces:** <APIs, events / topics, webhooks, shared libs whose contract changed — or "none">

## Data & contracts
- **Migrations:** <table / column, reversible?, needs a manual run?>
- **Backfills / one-offs:** <scripts or jobs that must run, and when>
- **Schemas & APIs:** <event / Avro / REST / GraphQL shape changes; backward compatible? who consumes them?>

## Gates & rollout
- **Flags / settings:** <name, default, who flips it>
- **Config / secrets:** <env vars, secrets that must exist before deploy>
- **Deploy order:** <e.g. 1. migration PR → run migration → 2. code PR; or "any order">

## Blast radius
**Direct:** <the code paths the diff changes>
**Indirect:** <callers, consumers of changed events / endpoints, shared modules, jobs / crons, reports — found by tracing outside the diff>

## Regression points
| # | What could break | Why (the shared path) | How to check |
|---|---|---|---|
| 1 | ... | ... | ... |

## Post-deploy watch
- <log query / log line, alert, chat channel, warehouse count — with the expected healthy signal>

## Who to notify
| Who | Why | Draft message |
|---|---|---|
| Ops (#channel or person) | ... | "<2–3 line message, plain English>" |
```

## Risk rating guide

- 🟢 **Low** — isolated, additive, gated, or internal-only; easy to roll back; no data/contract change.
- 🟡 **Medium** — touches a shared path, a client- or end-user-visible flow, or needs a manual step (migration, backfill, secret).
- 🔴 **High** — changes money, order state, or an external contract (webhooks, API, event schemas); irreversible data change; multi-repo deploy ordering; or hits many accounts at once.

Give the reason, not just the colour — the rating is only useful if someone can disagree with it.

Signals often conflict (e.g. "rewrites ~850 rows at once" says High, "re-derivable from the
source of truth, no money or blocking change" says Medium). Weigh **reversibility and the
people affected** most: a wide but re-derivable change sits lower than a narrow change that
cannot be undone. When it's borderline, say so ("🟡 Medium, near High") and name the deciding
factor.
