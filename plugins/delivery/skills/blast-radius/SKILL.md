---
name: blast-radius
description: Produce a formatted impact report for a whole change (a feature, bug fix or chore, often spanning several PRs across repos) covering a plain-English summary, client, end-user and internal-team impact, services modified, data/contract changes, gates and rollout, regression points, post-deploy watch, who to notify, and per-PR staging/prod deploy status; can post the report as a comment on each ticket, one report per ticket. With no input it picks up the work in progress in the session (several tickets if needed) and skips finished or deployed ones. Use when the user runs /delivery:blast-radius, with or without a ticket (ID or link, from Shortcut, Linear, Jira or GitHub) or GitHub PR link, or asks "what's the blast radius", "what does this change affect", "who does this impact", "what could this break", "regression risk", "impact analysis", "summarise this change for ops/finance/support", or wants to understand a change before merging, deploying, QA or announcing it, even if they don't say "blast radius".
---

# Blast radius

Explain what a change does to the system and to people: what we did in plain English, who
feels it (clients, end users, internal teams), which services and contracts moved, what could
regress, and what to watch after release.

A **change** is the whole piece of work, not one PR: a ticket often yields several PRs across
repos (a migration PR plus a code PR, a backend change plus a dashboard screen). Analyse them
together, because the interesting risks usually sit *between* PRs: deploy order, a contract one
side changes and the other consumes.

The analysis is **read-only**: it never merges, pushes, edits code or tickets, or triggers
automations. The report prints to the terminal. The only write is the optional last step,
posting the report as a comment on the ticket(s), and only after the user says yes.

## 0. Load your config

This skill is generic. Everything about your team (tracker, GitHub org, where clones live, how
deploys are detected, timezone, which repos reach which people) comes from the plugin's options
(`/config`) and the config folder `~/.claude/delivery-skills/`. Before starting, run
`${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/scripts/config_status.sh` and follow "First run" in `references/setup.md` for anything
missing. Below, `$GH_ORG`, `$TICKET_PREFIX`, `$CODE_ROOT`, `$TIMEZONE` and so on mean the values
it prints, and "the service map" means `~/.claude/delivery-skills/service-map.md`.

## 1. Identify the change(s)

Work out which change the user means, from whatever they gave:

| Input | How to resolve |
|---|---|
| Nothing | Use the session. See "Session with several tickets" below. |
| Ticket(s) (`<prefix>12345`, `12345`, a tracker URL, or several of them) | Read each with the tracker's MCP (load it via ToolSearch first): title, type, description, acceptance criteria, comments, epic, and linked branches/PRs. Then run `${CLAUDE_SKILL_DIR}/scripts/find_prs.sh <id>` for each. |
| GitHub PR URL / `repo#123` | `gh pr view` it. Pull the ticket ID from the head branch, title or body, then continue as for a ticket. If there's no ticket, the change is that PR alone. |
| Local branch, no PR yet | `git diff <default-branch>...HEAD` plus uncommitted changes. The ticket ID comes from the branch name. |

`${CLAUDE_SKILL_DIR}/scripts/find_prs.sh` searches the whole `$GH_ORG` org and labels each hit:
- **DIRECT**: the ticket ID is in the PR's title or branch. It's part of the change.
- **MENTION**: the ID appears only in the body. Usually it belongs to a *different* ticket that refers to this one (a follow-up, or a fix it depends on). Read the title and decide. If it's related but separate, list it under "Related" in the header instead of analysing it.

Leave out PRs that were closed without merging, unless they're the only trace of the work. List other tickets in the same epic in one line, but don't analyse them.

### Session with several tickets

With no input, report on the work that is **in progress now**, which may be several tickets
worked on in parallel. A long session also holds finished work, and that should be left out.

**Candidates** are tickets *worked on* in this session: code edited, committed, pushed, merged
to staging, PR'd, reviewed or QA'd. Look through the whole conversation, including any summary
of earlier context. Also check `git worktree list` in each repo touched for branches carrying a
ticket ID. A ticket that was only *mentioned* (related, blocked on, from a memory note) is not a
candidate.

**Drop the finished ones.** A candidate is finished when any of these is true:
- the user or the conversation closed it ("done", "shipped", "moving on");
- its tracker state is `$TICKET_DONE_STATE` (or any done state);
- all its PRs are merged and `deploy_status.sh` shows them in production.

What's left is the current work. Keep a ticket that is merged but not yet in production: it is
still in flight.

**Grouping:**
- **Several current tickets that form one change** become one combined report with a
  `Tickets:` line listing all of them. They form one change when they share PRs, one depends on
  the other, they touch the same code path or contract, or they were deliberately shipped
  together. Call out what happens *between* them: deploy order, conflicting clauses, one relying
  on the other being live.
- **Independent tickets** get one report each, one after another, with a short index at the top
  (ticket, one-line summary, risk).

Before analysing, state what you've resolved in one or two lines: the current tickets and their
grouping, plus the finished ones you skipped and why. For example: "Current: ENG-101 + ENG-102
(combined, both change the order-hold path). Skipped: ENG-95 (in prod), ENG-97 (Done)." If it's
ambiguous which work is current, ask. Otherwise proceed, since the user can correct you from
that line.

## 2. Gather the evidence

For each PR, `gh pr view <n> --repo $GH_ORG/<repo> --json title,body,files,commits,baseRefName,headRefName,state,reviewDecision,statusCheckRollup`
and `gh pr diff <n> --repo $GH_ORG/<repo>`. The PR body often states the intent, gates and
deploy notes, so use it, but trust the diff over the description when they disagree. Show CI
and review state in the PR table. If CI is red, check whether the same check is red on the
default branch before blaming the PR.

Compare the ticket's acceptance criteria with what shipped. A criterion that isn't met, or is
met differently (the ticket asked for a new error code and the PR reused an existing one), goes
on the header's **AC** line.

Then get each PR's deploy status:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/scripts/deploy_status.sh <repo> <pr-number>
```

It reports staging and production as YES, LIKELY (found via cherry-pick or a "Sync <ticket>
onto staging" overlay commit) or NO. It uses GitOps bump commits when `BUMP_PATH` is configured,
and GitHub Deployments otherwise.
A bump or deployment means a deploy was triggered, not that it's healthy. Say so if it matters.
An overlay commit may carry only part of the PR (config such as CronJobs or values files is
often left out), so diff the overlay against the PR when staging behaviour matters.

For **open PRs**, check that they still merge cleanly. A conflict or a clash (two ADRs with the
same number, two migrations with the same timestamp) is a real rollout step that people miss:

```bash
git -C <repo> fetch -q origin main "pull/<n>/head:refs/remotes/origin/pr-<n>"
git -C <repo> merge-tree --write-tree origin/main origin/pr-<n>   # exit 1 + CONFLICT lines = conflicts
```

The same `origin/pr-<n>` ref lets you `git grep` or `git show` the PR's version of a file
without checking anything out. In zsh, brace the variable in `"${ref}:path"`, because
`$ref:lib/...` reads `:l` as a lowercase modifier and silently changes the path.

**Serious clashes with other people's open PRs.** This is a quick scan, not a section of the
report. Report a clash only if it could actually cause harm:
- another open PR rewrites the **same function or clause**, so the second merge could silently
  drop one side's logic;
- two migrations would collide;
- a contract one PR changes, the other relies on.

Overlapping files, CHANGELOG edits and routine rebase conflicts are noise, so leave them out.
To find candidates, check the tracker's related or overlapping tickets and run
`gh pr list --repo $GH_ORG/<repo> --state open --json number,title,author,files --jq '.[] | select(any(.files[]; .path == "<file>"))'`.

When there is a real clash, add one row to Regression points: the PR and its author, the
clause, and what the second merge must keep. If nothing qualifies, say nothing. Don't comment
on someone else's PR on your own. The user decides whether to message the author or ask you to
leave a comment.

## 3. Trace the blast radius beyond the diff

The diff shows what changed. The blast radius is what *depends* on what changed. Identify the
change's "exports": functions/modules, API endpoints and response fields, events/topics and their
payloads, DB tables/columns, status/enum values, config keys, email templates, chat message
shapes. Then search for their consumers.

- **Inside the repo:** local clones live under `$CODE_ROOT` (laid out per `$REPO_GLOBS`).
  Search the up-to-date default branch without checking anything out (other worktrees share
  these repos): `git -C <repo> fetch -q origin && git -C <repo> grep -n '<symbol>' origin/main`
  (use the repo's own default branch if it isn't `main`).
- **Across repos:** contracts cross service lines. Examples: a core API's tracking fields feed a
  public status page, platform events feed webhooks and billing, CRM fields flow through a sync
  service. Search every clone's default branch at once with
  `${CLAUDE_PLUGIN_ROOT}/skills/blast-radius/scripts/grep_all_repos.sh -n -e '<endpoint|event|field>'`.
  Add `-f` to fetch first, or `-a` to include the slow repos in `$SLOW_REPOS`.
- **Beyond code:** automations (n8n, Zapier), CRM fields, BI models and dashboards, and chat
  alerts can all depend on a status value or column. Name these as *possible* consumers when you
  can't confirm them, and say so.

**Data written is an export too.** When the change writes to a table (a new job, a backfill, a
corrected status), the table's readers are in the blast radius even though the diff never
touches them: the screens, endpoints, emails and reports built on those rows. These are often
the most important findings and the ones the PR author didn't mention, so grep for the table
and column names across repos.

**Flags and secrets you can't read.** Flag values that live in encrypted files or cluster
secrets can't be checked read-only, so don't read secrets to find out. Name the flag, say its
prod value is unconfirmed, and say what changes in each state. Logs can sometimes show it
indirectly.

When tracing spans several repos, hand it to an `Explore` subagent and give it the list of
exports. It returns only the consumers it finds, which keeps the main context lean.

Read the service map to translate "repo X changed" into "these people are affected". It also
lists repo-specific traps worth a regression point or rollout note (migrations not run on
deploy, a deploy that aborts on a missing secret, schema fields that need a default). When the
report finds a new hidden reader or trap, offer to add it to the service map.

## 4. Write the report

Use the structure in `references/report-template.md`, in that order. A few things make the
report worth reading:

- **"What we did" is for anyone in the company.** Describe the problem and the new behaviour
  in plain words, with no file names or jargon. If someone from Ops reads only this paragraph,
  they should know what changed for them.
- **Separate the external audiences** listed in the service map (for example clients vs. their
  end users). A change can be invisible to one and very visible to the other.
- **Be concrete.** Name the screen, endpoint, column, flag, channel or template. "May affect
  orders" helps no one. "Orders held by a blocked account are now released when it's unblocked,
  through `ReleaseHeldOrders` in core-api" does.
- **Label inference.** Separate what the diff proves from what you're inferring ("likely",
  "possible consumer, not confirmed"). A confident wrong claim in an impact report is worse than
  an honest "unknown".
- **Make every regression point checkable.** Say what could break, which shared path links it to
  this change, and how to check it (a test, a query, a screen to click, a log line).
- **Give a reason with the risk rating.** Use the guide in the template.
- **Make "Who to notify" usable.** Give a draft message per audience that can be pasted as-is.

Print the report in the terminal, then go to step 5.

## 5. Offer to post it to the ticket

(When `/delivery:ship-it` runs this skill, skip the offer. ship-it posts each ticket's report itself.)

After printing, offer once in a single line to post the report as a comment on the ticket(s)
it covers, so it becomes the ticket's record of the change. Posting is visible to the whole
team, so wait for a yes. Don't post on your own initiative, even if the user has said yes to a
previous report.

On yes, use the tracker MCP's create-comment tool (load it via ToolSearch first).

**One ticket, one report.** Each ticket gets a report about that ticket only. Never post the
same combined report to several tickets: someone reading ticket A's comment needs A's PRs,
impact and risk, not a mix with B. When the terminal report combined several tickets, redo it
per ticket before posting:
- scope it to that ticket's own PRs;
- rewrite every section for that ticket alone, including "What we did", impact, regression
  points and risk;
- reuse the evidence already gathered rather than re-fetching it;
- keep what happens between the tickets as one line under **Related**, for example
  "Interacts with ENG-102: both edit the blocked-submit clause; whichever merges second must
  keep `maybe_record_block_hold`."

Show the per-ticket versions in the terminal before posting them. Once the user confirms, post
each one on its own ticket.

- **What to post:** the ticket's **full** report as markdown. Include every template section
  (header, PR table, What we did, External impact, Internal impact, Technical changes, Data &
  contracts, Gates & rollout, Blast radius, Regression points, Post-deploy watch, Who to
  notify), and never shorten or summarise it, because the comment is the ticket's permanent
  record. Add a footer, because deploy status goes stale fast:
  `_Generated by /delivery:blast-radius on <YYYY-MM-DD HH:MM> <$TIMEZONE>. Deploy status is as of then._`
- **Re-runs:** if the tracker can't edit or delete comments and the ticket already has a
  blast-radius comment, start the new one with `Supersedes the blast-radius report of <date>.`
  so readers know which is current.
- **Leave out sensitive details:** secret values (never include those), customer personal
  details and internal credentials. Account IDs and order IDs are fine.

Then give the comment link(s) back to the user.

## Tailoring

The report gets sharper as the service map grows. See "Tailoring" in `references/setup.md`.
The most valuable additions are deploy quirks per repo, hidden data readers, and your GitOps
deploy signals.
