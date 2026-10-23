# ship-it message drafts

Write the drafts for people, not for engineers. Each one should make sense to its reader
without the blast-radius report open next to it. Use your chat tool's formatting. For Slack that's mrkdwn: `*bold*`, `_italic_`, `•` bullets,
`<url|text>` links. Slack doesn't render markdown tables, so use a code block for anything
table-shaped.

## 1. Team messages (one per affected audience)

Base these on the blast-radius **Who to notify** and **Internal impact** sections. Write one
message per audience (Finance, Ops, Support, Account managers, Integrations and so on), and skip any audience
the change doesn't really affect. Each message answers four questions, in this order:

1. **What changed for you**: one or two plain sentences with no repo names.
2. **When**: live since <date/time>, or live after <step>.
3. **Anything you need to do**: concrete, or "Nothing, just FYI".
4. **Feedback we need**: a specific question if there is one ("Is 30 days the right cut-off
   for holding orders?"); otherwise leave this out.

Suggest the destination, a channel or a person to DM, and name it in the draft header. The
user can redirect any draft before it's posted.
- **One team:** use its row in `channels.md`.
- **Several teams** (for example finance and sales): look for one shared cross-department
  channel instead of repeating the news per team. Follow the "Changes that affect several
  teams" section of `channels.md`.
- **Team not listed:** say so and suggest the most likely channel from a channel search in the
  chat tool. Don't guess an ID. Once the user confirms a channel, add it to `channels.md`.

```
*Heads-up: <plain-English title>* (<ticket>)
<What changed for you.>
*Live:* <when>
*What you need to do:* <action | Nothing — FYI>
*We'd love your input on:* <question>   ← only if there is one
```

## 2. Deploy-watch channel: regression watch

This message is written for whoever triages an incident in the next 24–48 hours, including AI
agents that read the channel. They need to match a symptom to this deploy quickly.
Make it scannable and keyword-rich: name the services, endpoints, tables, job names and error
strings someone would actually search for.

```
:rocket: *Deployed: <title>* — <ticket> · <repos> · live <YYYY-MM-DD HH:MM> <timezone>
<one line: what changed>
*If you see any of these in the next 48h, suspect this deploy first:*
```
Then a code block, one row per regression point from the blast-radius table:

```
Symptom                                   | Where to look                         | Likely cause
Orders released for still-blocked account | core-api log "releasing held orders"  | partial account event read as unblock
...
```

End with: `Rollback: <revert PR / flag / steps>` · `Owner: <@OWNER_CHAT_ID>` · `<ticket link>`.
Use `<@USERID>` for Slack mentions. Plain `@Name` text doesn't notify anyone.

## 3. Shipped channel: announcement

One or two lines at most. Describe the outcome for people, not the implementation. Add one
emoji if it fits.

```
:white_check_mark: <Outcome in plain words> — <who benefits>. (<ticket>)
```

Example: `:white_check_mark: Clients' stuck orders now release automatically the moment their
account is unblocked — no more manual hunting by Ops. (ENG-101)`

## Follow-ups worth a ticket (list only)

The bar is high. Include something only if leaving it alone risks money, orders, data, an
incident, or a repeat of manual work someone is already doing. Polish, refactors and
"would be nice" don't qualify. For each one: a one-line title, why it matters (the concrete
risk), and where it came from (a regression point, a review comment, something found during
the work). It's fine for the list to be empty. Say so: "No follow-ups worth a ticket."
