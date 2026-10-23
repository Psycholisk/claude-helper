# Comms destinations

Who gets ship-it messages, and where. Add or fix a row whenever the user confirms a channel or
person, with the date. Use real IDs (`C…` / `U…` in Slack) so posts don't depend on a name
search. Rows in `<…>` are placeholders still to fill.

| Audience | Destination | ID | Why this one / how to post |
|---|---|---|---|
| Deploy regression watch | `<#deployments>` | `<id>` | Where each deploy's regression-points message goes. Read by whoever triages incidents in the next 48h. |
| Incidents (live problems) | `<#incidents>` | `<id>` | Only for a real 🔴 problem found in watch mode, not the routine regression watch. |
| Shipped announcements | `<#shipped>` | `<id>` | One or two lines, outcome-first. |
| Finance | `<channel>` | `<id>` | |
| Ops | `<channel>` | `<id>` | |
| Sales / Account managers | `<channel>` | `<id>` | Cc a user group only when they need to act. |
| Support | `<channel, or a thread reply on the #shipped post with @-mentions>` | `<id>` | Prefer their channel for announcements over their working queue. |
| Tech leads | `<channel>` | `<id>` | Technical heads-ups, ADR reviews. |
| Owner mention | `<your name>` | `<user id>` | `<@USERID>` |

## Changes that affect several teams

When one message concerns two or more teams (for example finance and sales), look for a
cross-team channel instead of posting the same news in each team's channel. Search the chat tool
using both teams' keywords. Check that the channel is active (read its last ~10 messages) and
that the right people actually talk there. Suggest it in the draft header, with the single-team
channels as the alternative. The user can always redirect a draft before it's posted.

Known cross-team channels (verify activity before suggesting):

| Teams | Channel | ID |
|---|---|---|
| `<Finance + Sales>` | `<channel>` | `<id>` |
