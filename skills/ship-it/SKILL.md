---
name: ship-it
description: Post-merge close-out for one or more tickets shipped together, the step after /build-it. Communications, cleanup and monitoring are combined across tickets; each ticket gets its own blast-radius report. It waits until the merged PRs are actually live in production, cleans up the tickets' worktrees and branches, posts a /blast-radius report on each ticket, moves the tickets to done, then drafts team, deploy-watch and shipped-announcement messages for your chat tool for approval, proposes todo-app tasks for daily post-deploy monitoring, and lists follow-ups worth a ticket. Also has a watch mode (`/ship-it watch <ticket>`) that runs one day's post-deploy health check. Use when the user says "ship it", "/ship-it", "we merged, wrap it up", "close out <ticket>", "it's deployed, do the post-deploy stuff", "announce this deploy", or pastes a "/ship-it watch" line from a monitoring task.
---

# ship-it

Close out shipped work: confirm it's live, tidy up, record it, tell people, and watch it for a
few days. The step before this is `/build-it` (build, PR, staging), and usually `/qa-it`. The
report itself comes from `/blast-radius`.

## Config

This skill is generic. Your team's setup lives in `~/.claude/delivery-skills/`:
- `config.env`: tracker and its done state, chat tool, todo app, timezone, working days, check
  time;
- `channels.md`: which channel or person each audience hears from (copy it from
  `~/.claude/skills/ship-it/templates/channels.md` on first use);
- `service-map.md`: manual deploy steps per repo;
- `capabilities.md`: how to read logs, the cluster and the error tracker, for watch mode.

Run the first-run check in `~/.claude/skills/blast-radius/references/setup.md` before starting.
Below, "the deploy-watch channel", "the shipped channel" and "the incidents channel" mean the
rows of those names in `channels.md`. Only ask for a missing value when the step that needs it
comes up.

**Who approves what.** Some writes are routine bookkeeping and happen automatically. Anything
that speaks to people waits for an explicit yes.

| Action | Mode |
|---|---|
| Worktree and branch cleanup | Automatic (safe cases only, see step 3) |
| Blast-radius comment on each ticket | Automatic |
| Moving tickets to done | Automatic |
| Monitoring tasks in the todo app | Ask first |
| Team messages, deploy-watch, shipped announcement | Draft only. Post only what the user names ("post 1 and 3"). |
| Follow-ups | List only. The user creates tickets themselves or asks you to. |

Chat posts go out **as the user** through their own chat connector, never through a bot
account. An earlier yes to one message doesn't cover another message, or the same message in
another run.

## Output format

Every run prints the same sections in the same order, using the fixed layouts in
`references/output.md`:
1. header
2. live check
3. cleanup
4. tickets
5. drafts
6. monitoring
7. follow-ups
8. close-out checklist

Lists are tables, and details are headed sections with bullet sub-items under them. Never
improvise a different layout. The user wants every run to look the same. Watch mode has its own
fixed layout in the same file.

## The goal

Treat each ticket's close-out as a goal with a fixed checklist. A run is finished when every
item is ✅ done, ⏭️ skipped (by the user's decision, or because it was already done), or 🚫
not needed. "Couldn't verify" never quietly turns into done. When you can't settle an item
yourself, **stop and ask**. Typical cases: a deploy you can't observe, a manual step only the
user can do, an open PR.

**The user's answer settles it.** "It's deployed" → mark it ✅ (confirmed by the user) and carry
on. "Skip it" → mark it ⏭️ and carry on. Don't re-check or argue. Keep a ticket that's blocked
on a question from holding up the other tickets: finish whatever else you can, then ask all the
questions together.

Checklist. Items 1–5 are tracked **per ticket**. Items 6–8 are tracked **once for the whole run**:
1. All PRs merged
2. Every service live in production
3. Worktrees and branches cleaned up
4. Blast-radius report posted on the ticket
5. Ticket moved to done
6. Drafts presented: team messages, deploy-watch, shipped announcement
7. Monitoring plan proposed
8. Follow-ups listed

End every run with this checklist, in the "Close-out checklist" layout from
`references/output.md`.

## Modes

- `/ship-it` with nothing after it: close out the work in progress in this session. That may be
  several tickets.
- `/ship-it <ticket> <ticket>`: close out those tickets together.
- `/ship-it watch <ticket> [<ticket>] [day N of M]`: run one monitoring check. See "Watch mode".

## Several tickets in one run

One run can close out several tickets, shipped together. The user experiences it as **one**
close-out:
- **Combined:**
  - one live check;
  - one cleanup pass;
  - one set of drafts (each team gets one message covering every ticket that affects it; one
    deploy-watch message; one shipped message);
  - one monitoring plan;
  - one follow-ups list.

  Inside each combined message, keep the tickets distinguishable: name each ticket's ID next to
  its part, so a reader knows what belongs to which.
- **Split:** only the per-ticket record. Each ticket gets its **own** blast-radius report posted
  on itself (step 4) and is completed on its own (step 5). Never post a combined report on a
  ticket.

## 1. Resolve the tickets

With explicit input (tickets or PR links), always process them, whatever state they're in. For
a PR link, resolve its ticket the way `/blast-radius` does.

With no input, use `/blast-radius`'s session rules (`~/.claude/skills/blast-radius/SKILL.md`,
step 1) with one difference. Blast-radius drops tickets that are done or in production.
ship-it **keeps** them, because the user often deploys, cleans up or completes a ticket as a
separate step before running ship-it. For ship-it, a ticket only counts as finished once it has
already been closed out: it carries a blast-radius or ship-it comment posted after its PRs went
live.

List each ticket's PRs with `~/.claude/skills/blast-radius/scripts/find_prs.sh <id>`, and state
the tickets and PRs in one line before starting. See "Several tickets in one run" for what is
combined and what is split.

**Every step checks before acting.** Work already done by the user, or by an earlier run, is
normal. It isn't a reason to stop. Each step first looks at the current state:
- the PR is already live in production;
- no worktrees are left;
- the ticket already has a close-out comment;
- the ticket is already done;
- the announcement was already posted.

If so, mark that item ✅ already done and move on to the next step, without a second comment,
state change or post. Only the items that are missing actually run.

## 2. Make sure it's live

Merged isn't the same as deployed. For each PR, run
`~/.claude/skills/blast-radius/scripts/deploy_status.sh <repo> <pr>`. It reads GitOps bump
commits (if configured) and GitHub Deployments.

- **Open (not merged) PRs:** stop for that ticket and ask. This skill is for merged work.
- **Automated deploys still running** (merged, bump or deployment pending): wait for them. Run
  `~/.claude/skills/ship-it/scripts/wait_for_deploy.sh <repo>#<pr> ...` with Bash
  `run_in_background`. It exits once everything is live (0) or after 45 minutes (1). Do step 3
  and draft the messages while you wait. If it times out, report what's still pending and ask.
- **Can't tell** (`unknown`, no deploy signal, a service you can't observe): don't guess.
- **Manual steps** the deploy can't do by itself: the ones listed for the repo in the service
  map's "Manual deploy steps" (hand-run migrations, a release tag, a redeploy of another app),
  plus any one-off or backfill the ticket requires. List them with the exact command or step.
  Don't run production migrations, tags or backfills yourself unless the user tells you to.

In both of the last two cases, stop and ask. Show a per-service status table (✅ live / ⏳
deploying / ❓ can't tell / ✋ manual step) and ask "Deployed, or skip?" for each open row.
Take the answer as final, as described in "The goal".

Everything below this point needs the ticket to be live or settled by the user.

## 3. Clean up worktrees

Do one pass for all the tickets: run the script once per ticket ID and report the results
together.

```bash
~/.claude/skills/ship-it/scripts/cleanup_worktrees.sh <id>            # dry run
~/.claude/skills/ship-it/scripts/cleanup_worktrees.sh <id> --apply
```

It only removes worktrees that belong to the ticket, are clean, and whose PR is merged. That
includes per-ticket staging-prep worktrees such as `_staging-<ticket>-…`. It then deletes the
local branch (`-d`, never `-D`), deletes the remote branch if it's still there, and prunes.
Dirty or unmerged worktrees are skipped and reported. Don't force them: other sessions share
these clones. Report the result in a line or two.

## 4. Post the blast-radius report on each ticket (automatic)

For each ticket, follow `/blast-radius` for **that ticket alone**: run it as
`/blast-radius <ticket>`, so the report covers only that ticket's PRs. Then post it with the
tracker MCP's create-comment tool, without asking. Post the **complete** report with every
section of the template filled in. Never shorten or summarise it: the comment is the ticket's
permanent record. If the user settled a deploy by hand in step 2, say so in the PR table
("✅ confirmed by <OWNER_NAME>" or "⏭️ skipped"). Follow blast-radius step 5's rules for
the "Supersedes" line and what to leave out. Use this footer instead of blast-radius's own, so
readers know it was an automatic close-out post:
`_Posted by /ship-it (via /blast-radius) on <YYYY-MM-DD HH:MM> <$TIMEZONE>. Deploy status is as of then._`
Keep the reports from this step, because steps 5–7 are built from them. In particular, the team
messages in step 6 start from the report's "Who to notify" drafts and are reshaped into the
messages.md format, rather than written from scratch.

## 5. Complete the tickets (automatic)

Move each ticket to its workflow's `$TICKET_DONE_STATE` state with the tracker MCP. Look up the
state's ID in the ticket's own workflow (it can differ per team or project). Once you know it,
offer to note it in `config.env` so later runs skip the lookup.

Hold a ticket back, and say why, if its report lists a required step that isn't done yet: a
pending migration, backfill or flag flip that the change depends on. A follow-up idea, an ADR
still awaiting review, or a team's feedback doesn't count as a required step. Mention them, but
complete the ticket.

## 6. Drafts and proposals

Present the drafts table (D1, D2, …) with each draft's full text below it, ready to post or
copy, exactly as laid out in `references/output.md`. The formats are in
`references/messages.md`, and destinations are in `channels.md`.

**Don't duplicate announcements.** Before drafting, search the chat tool for the ticket ID and
the feature name since it went live, in the target channels. If the user already announced it
somewhere, don't draft a second message there. At most, suggest a thread reply on their post,
for example to ask for the feedback the ticket still needs.

1. **Team messages**, one per affected audience, each with its suggested channel or person.
2. **Deploy-watch channel**: the regression-watch message with the regression-points table.
3. **Shipped channel**: one or two lines.
4. **Monitoring plan**: the todo-app tasks you'd create (see step 7). Ask whether to create them.
5. **Follow-ups worth a ticket**: a list only, with a high bar. "None" is a fine answer.

With several tickets, the drafts are combined:
- **Teams:** each team gets one message covering every ticket that affects it, with a short
  section per ticket and its ID.
- **Deploy-watch:** one message, with a row per regression point and a Ticket column.
- **Shipped:** one message, one line per ticket. One line can cover several tickets only if
  they form a single outcome.
- **Follow-ups:** one list, each item tagged with its ticket.

The user can still ask for any of them to be split.

Then stop and wait. Post exactly the items the user approves, as written or with their edits,
and send back the message links.

## 7. Monitoring tasks (todo app, after a yes)

How long to monitor depends on blast-radius risk. With several tickets, **one** plan covers them
all: it lasts as long as the riskiest ticket needs, and lower-risk tickets drop off once their
own length is reached. Count **working days** (`$WORK_DAYS`, in `$TIMEZONE`) from the first
working day after the change went live:

| Risk | Checks |
|---|---|
| 🟢 Low | 1 working day |
| 🟡 Medium | 3 working days |
| 🔴 High | 5 working days, plus one check 7 calendar days after the last |

Create one task per check in `$TODO_PROJECT` of `$TODO_APP`, through its MCP (batch-create if it
has a batch tool):
- **title:** `Watch <ticket>[ + <ticket>] <short title> — day N/M`
- **due:** that day at `$CHECK_TIME` in `$TIMEZONE`, with a reminder at the due time
- **content:** first line `/ship-it watch <ticket> <ticket> day N of M`, listing only the
  tickets still under watch that day, so the user can paste it into a new session. Then one line
  per ticket on what the change is, then the ticket links. The full context lives in each
  ticket's blast-radius comment, so keep the task short.

If `TODO_APP` is `none`, or its MCP isn't connected, print the tasks as a list the user can add
by hand (or offer calendar events instead). Show the dates before creating anything.

## Watch mode: `/ship-it watch <ticket> [<ticket> …] [day N of M]`

This runs in a fresh session, usually pasted from a monitoring task. The goal is one clear
verdict for today.

1. **Load the context.** For each ticket, read it and its latest blast-radius comment. That
   comment has the PRs, Post-deploy watch, Regression points and the time it went live. If
   there's no comment, run `/blast-radius <ticket>` first. With several tickets, run every
   ticket's checks, but give one combined report: an overall verdict, then a section per
   ticket.
2. **Pick the time window.** Check from the previous check (the day before at `$CHECK_TIME`)
   until now. On day 1, start from the time it went live.
3. **Run every Post-deploy watch item** and each regression point's "How to check", read-only,
   using the recipes in `capabilities.md`:
   - **Logs:** the log tool's query for the window, filtered to the services and strings in
     the report.
   - **Cluster:** pods restarting or scheduled jobs failing, in the prod context.
   - **Chat:** search the incidents channel, the deploy-watch channel, the team channels you
     notified, and alert channels in the window for the feature's keywords, ticket ID and
     error strings.
   - **Error tracker:** if its connector is authenticated. Otherwise say it was skipped.
   - **Tracker:** new bugs or comments that mention the ticket or the feature.
   - **Database checks:** only the read-only queries listed in the report.
4. **Report.** Start with the verdict: ✅ all good, ⚠️ needs a look, or 🔴 problem. Then give one
   line per check with its evidence (a count, a log line, a link). A check that couldn't run is
   reported as skipped, never as passed.
5. **On the last day,** recommend stopping, or extending with a reason. Only create more
   monitoring tasks if the user says yes.

Don't post anything in watch mode unless asked. If something is 🔴, draft an incidents-channel
follow-up or a ticket comment and offer it.

## Tailoring

ship-it gets sharper as `channels.md` (with real IDs and cross-team channels), the service
map's manual deploy steps, and `capabilities.md`'s log and cluster recipes fill in. See
"Tailoring" in `~/.claude/skills/blast-radius/references/setup.md`.
