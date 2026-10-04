# Tracker adapters

How `build-it` talks to each tracker. The **project profile** decides which adapter applies and where its credentials come from; this file only describes the operations. Every adapter needs the same five operations:

| Operation | Used in |
|-----------|---------|
| **read** — title, description, acceptance criteria, tasks/checklist, comments, links | Phase 0 |
| **list states** — the workflow states available to this ticket, by name and id | Phase 0, 7 |
| **move** — set the ticket's state | Phase 0 (start), Phase 7 (hand-off) |
| **comment** — post a comment | Phase 7 |
| **link PR** — attach the PR to the ticket, or confirm the integration already did | Phase 3 |

**Resolve states by name, not by hardcoded id**, unless the profile pins ids. Match the profile's state names case-insensitively. When the profile gives none, use: start = the first of `In Progress`, `Started`, `Doing`; hand-off = the first of `Ready for QA`, `In QA`, `QA`, `In Review`. If no hand-off state exists, don't invent one: leave the ticket where it is and post the hand-off comment.

## Recognising the tracker from a ticket

| Ticket looks like | Tracker |
|-------------------|---------|
| `sc-123`, `app.shortcut.com/<workspace>/story/123` | Shortcut |
| `ABC-123` with a `linear.app/<workspace>/issue/ABC-123` URL, or a team key the profile says is Linear | Linear |
| `#123`, `owner/repo#123`, `github.com/<owner>/<repo>/issues/123` | GitHub Issues |
| `ABC-123` with an `<site>.atlassian.net/browse/ABC-123` URL | Jira |

A bare `ABC-123` is ambiguous between Linear and Jira: use the profile, or the project's `CLAUDE.md`, or ask.

## Connections and credentials

Each adapter supports an **MCP** connection and a **REST** fallback. The profile says which to use and how credentials are loaded. Conventional environment variable names are below; a profile may point elsewhere.

- Load credentials with the profile's `load` command in the **same shell command** that uses them (e.g. `. ~/.config/acme/tracker.env && curl ...`), because shell state doesn't persist between tool calls.
- Never echo a token, and never put one in a URL or a commit.
- `jq` may not be installed; parse JSON with `python3 -c` if it's missing.

---

## Shortcut

- **MCP:** tools named like `mcp__<server>__stories-get-by-id`, `stories-update`, `stories-create-comment` (search with ToolSearch `shortcut`).
- **REST:** base `https://api.app.shortcut.com/api/v3`, header `Shortcut-Token: $SHORTCUT_API_TOKEN`, `Content-Type: application/json`.

| Operation | REST |
|-----------|------|
| read | `GET /stories/{id}` (includes `tasks`, `comments`, `branches`, `pull_requests`, `formatted_vcs_branch_name`) |
| list states | `GET /workflows/{workflow_id}` → `states[]` (`id`, `name`, `type`); the story's `workflow_id` says which workflow |
| move | `PUT /stories/{id}` `{"workflow_state_id": <id>}` |
| check a task | `PUT /stories/{id}/tasks/{task_id}` `{"complete": true}` |
| comment | `POST /stories/{id}/comments` `{"text": "..."}` |
| link PR | Usually automatic: the GitHub integration links any branch, commit or PR whose text contains `sc-<id>`. Confirm with `GET /stories/{id}` → `pull_requests`. |

Gotchas:
- The GitHub integration links **every** `sc-<id>` it sees in branch names, commit messages and PR text, and a workspace automation may move each linked story. Only write the id of the story you're implementing; name related stories in words.
- `PUT /stories/{id}` with `pull_request_ids` or `external_links` **replaces** the list — read it first and send the full list back.
- Creating stories may need a workflow and team (`group_id`); take them from the profile.

## Linear

- **MCP:** tools named like `mcp__<server>__get_issue`, `list_issue_statuses`, `save_issue`, `save_comment` (search with ToolSearch `linear`). If several Linear servers are connected, use the one the profile names.
- **REST:** GraphQL at `https://api.linear.app/graphql`, header `Authorization: $LINEAR_API_KEY`.

| Operation | MCP / GraphQL |
|-----------|---------------|
| read | `get_issue` / `issue(id: "ABC-123") { title description state { name } comments { nodes { body } } attachments { nodes { url } } branchName }` |
| list states | `list_issue_statuses` for the issue's team / `team(id) { states { nodes { id name type } } }` |
| move | `save_issue` with the new state / `issueUpdate(id, input: { stateId })` |
| comment | `save_comment` / `commentCreate(input: { issueId, body })` |
| link PR | Usually automatic when the branch name or PR title contains the issue key and Linear's GitHub integration is installed; otherwise `create_attachment` / `attachmentLinkURL(issueId, url)`. |

Gotchas:
- Linear's `branchName` is the branch its GitHub integration expects; prefer it when the profile says so.
- Many Linear teams have no QA state. The default hand-off is then a comment, with the state left as the profile says (often `In Review` or unchanged).

## GitHub Issues

- **CLI:** `gh` (already authenticated for PR work). No extra credentials.

| Operation | Command |
|-----------|---------|
| read | `gh issue view <n> -R <owner/repo> --comments` |
| list states | Issues only have open/closed. A "state" is usually a label (`gh label list`) or a Projects field (`gh project item-list`); the profile says which. |
| move | `gh issue edit <n> --add-label <x> --remove-label <y>`, or `gh project item-edit` for a Projects status field |
| comment | `gh issue comment <n> --body ...` |
| link PR | Put `Closes #<n>` (same repo) or `Closes <owner/repo>#<n>` in the PR body. It closes the issue only when the PR merges, which stays the human's call. |

## Jira

- **MCP:** an Atlassian/Jira MCP server if one is connected (search with ToolSearch `jira`).
- **REST:** `https://<site>.atlassian.net/rest/api/3`, basic auth `$JIRA_EMAIL:$JIRA_API_TOKEN`.

| Operation | REST |
|-----------|------|
| read | `GET /issue/{key}?expand=renderedFields` and `GET /issue/{key}/comment` |
| list states | `GET /issue/{key}/transitions`. Jira moves through **transitions**, not states: pick the transition whose target status has the profile's name. |
| move | `POST /issue/{key}/transitions` `{"transition": {"id": "<id>"}}` |
| comment | `POST /issue/{key}/comment` with an Atlassian Document Format body |
| link PR | Automatic with the GitHub-for-Jira app when the key is in the branch or PR title; otherwise `POST /issue/{key}/remotelink` |
