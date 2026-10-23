#!/usr/bin/env bash
# Find every PR across the GitHub org that belongs to a ticket.
#
# Usage: find_prs.sh <ticket-id>      e.g. find_prs.sh 29035  (or sc-29035)
#
# Reads GH_ORG and TICKET_PREFIX from ~/.claude/delivery-skills/config.env.
#
# Why the classification: GitHub search matches the ID anywhere in title OR body,
# so a PR for a *different* ticket that merely mentions this one ("follow-up to
# sc-30663") shows up too. We only treat a PR as part of the change when the ID is
# in its title or head branch; body-only hits are printed as MENTION for a human
# (or the model) to judge.
#
# Output: one TSV line per PR:
#   DIRECT|MENTION  repo  number  state  headBranch  baseBranch  mergedAt  url  title
set -euo pipefail

cfg="${DELIVERY_SKILLS_HOME:-$HOME/.claude/delivery-skills}/config.env"
# shellcheck source=/dev/null
[[ -f "$cfg" ]] && source "$cfg"
[[ -n "${GH_ORG:-}" && "$GH_ORG" != \<* ]] || { echo "GH_ORG not set in $cfg (see blast-radius/references/setup.md)" >&2; exit 2; }
prefix="${TICKET_PREFIX:-}"; [[ "$prefix" == \<* ]] && prefix=""

id="${1:?usage: find_prs.sh <ticket-id>}"
# accept "123", "sc-123" or "SC-123": strip the prefix case-insensitively
shopt -s nocasematch; [[ -n "$prefix" && "$id" == "$prefix"* ]] && id="${id:${#prefix}}"; shopt -u nocasematch
needle=$(tr '[:upper:]' '[:lower:]' <<<"${prefix}${id}")

gh search prs "$needle" --owner "$GH_ORG" --limit 100 \
  --json repository,number,url --jq '.[] | "\(.repository.nameWithOwner) \(.number)"' |
while read -r repo num; do
  gh pr view "$num" --repo "$repo" \
    --json number,title,state,headRefName,baseRefName,mergedAt,url \
  | jq -r --arg n "$needle" --arg repo "$repo" '
      (if ((.title + " " + .headRefName) | ascii_downcase | contains($n)) then "DIRECT" else "MENTION" end) as $kind
      | [$kind, $repo, (.number|tostring), .state, .headRefName, .baseRefName, (.mergedAt // "-"), .url, .title]
      | @tsv'
done | sort
