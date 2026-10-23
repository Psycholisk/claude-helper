#!/usr/bin/env bash
# Where is a PR's code right now? Open / on staging / live in production.
#
# Usage: deploy_status.sh <repo> <pr-number>     e.g. deploy_status.sh billing 606
#
# Reads GH_ORG, TICKET_PREFIX, the branch names and the deploy signals from
# ~/.claude/delivery-skills/config.env.
#
# How it decides, in order:
#   1. GitOps bump commits (when BUMP_PATH is set): CI writes a commit like
#      "[no ci] Bump prod to 1234" touching BUMP_PATH, and ArgoCD/Flux rolls it out. Code is
#      "deployed to env X" when it is contained in the latest bump commit for X on that env's
#      branch (PROD_BRANCH / STAGING_BRANCH).
#   2. Otherwise GitHub Deployments: the latest *successful* Deployment for the environment
#      (PROD_DEPLOY_ENV / STAGING_DEPLOY_ENV, case-insensitive). Covers Vercel, Encore, and any
#      CI that reports deployments.
# Containment is checked by SHA first, then by commit subject, because staging is often
# fed by cherry-picks (new SHAs), and release flows may cherry-pick develop -> main.
#
# Caveat: a bump or deployment means a deploy was *triggered*. When it really matters
# (incident, "is it live?"), confirm the running image in the cluster.
set -euo pipefail

cfg="${DELIVERY_SKILLS_HOME:-$HOME/.claude/delivery-skills}/config.env"
# shellcheck source=/dev/null
[[ -f "$cfg" ]] && source "$cfg"
[[ -n "${GH_ORG:-}" && "$GH_ORG" != \<* ]] || { echo "GH_ORG not set in $cfg (see blast-radius/references/setup.md)" >&2; exit 2; }
prefix="${TICKET_PREFIX:-}"; [[ "$prefix" == \<* ]] && prefix=""
prod_branch="${PROD_BRANCH:-main}"; staging_branch="${STAGING_BRANCH-staging}"
bump_path="${BUMP_PATH:-}"; bump_prefix="${BUMP_PREFIX:-[no ci] Bump}"

repo="${1:?usage: deploy_status.sh <repo> <pr>}"; pr="${2:?usage: deploy_status.sh <repo> <pr>}"
repo="${repo#"$GH_ORG"/}"; full="$GH_ORG/$repo"

pr_json=$(gh pr view "$pr" --repo "$full" --json state,mergedAt,mergeCommit,headRefOid,commits,baseRefName,headRefName,title,files)
state=$(jq -r .state <<<"$pr_json")
head_sha=$(jq -r .headRefOid <<<"$pr_json")
merge_sha=$(jq -r '.mergeCommit.oid // empty' <<<"$pr_json")
subjects=$(jq -r '.commits[].messageHeadline' <<<"$pr_json")
ticket=""
[[ -n "$prefix" ]] && ticket=$(jq -r '.headRefName + " " + .title' <<<"$pr_json" | grep -ioE -- "${prefix}[0-9]+" | head -1 || true)

# latest "<BUMP_PREFIX> <env> ..." commit touching BUMP_PATH on a branch (none if unset)
latest_bump() { # $1=branch $2=env word in the bump subject
  [[ -n "$bump_path" ]] || return 0
  gh api "repos/$full/commits?sha=$1&path=$bump_path&per_page=30" 2>/dev/null \
    | jq -r --arg p "$bump_prefix $2" \
        '[.[] | select(.commit.message | ascii_downcase | startswith($p | ascii_downcase)) | .sha] | first // empty' 2>/dev/null || true
}

# latest GitHub Deployment for an environment whose newest status is "success"
latest_deployment() { # $1=env name
  local id st
  for id in $(gh api "repos/$full/deployments?environment=$1&per_page=10" --jq '.[].id' 2>/dev/null); do
    st=$(gh api "repos/$full/deployments/$id/statuses?per_page=1" --jq '.[0].state // empty' 2>/dev/null || true)
    if [[ "$st" == success ]]; then
      gh api "repos/$full/deployments/$id" --jq .sha 2>/dev/null; return
    fi
  done
}

# is $2 (a sha) contained in $1 (a ref)?  compare base...head: "behind"/"identical" => contained
contains_sha() {
  local st; st=$(gh api "repos/$full/compare/$1...$2" --jq .status 2>/dev/null || echo error)
  [[ "$st" == "behind" || "$st" == "identical" ]]
}

# recent first-line commit subjects reachable from a ref (200 is plenty: bumps are frequent)
recent_subjects() {
  for page in 1 2; do
    gh api "repos/$full/commits?sha=$1&per_page=100&page=$page" --jq '.[].commit.message | split("\n")[0]' 2>/dev/null || true
  done
}

# fallback 1: every PR commit subject appears in the ref (cherry-picks keep subjects).
# GitHub truncates long headlines with "…", so match on the prefix.
contains_subjects() { # $1=subject log
  local s
  while IFS= read -r s; do
    s="${s%…}"
    [[ -z "$s" || "$s" == Merge* ]] && continue
    awk -v p="$s" 'index($0, p) == 1 { found=1 } END { exit !found }' <<<"$1" || return 1
  done <<<"$subjects"
}

# fallback 2: some repos feed a diverged staging with one squashed
# "Sync sc-XXXX onto staging" overlay commit, so look for the ticket ID itself.
mentions_ticket() { # $1=subject log
  [[ -n "$ticket" ]] && grep -iF -- "$ticket" <<<"$1" | head -1
}

check_env() { # $1=label $2=branch $3=bump env word $4=GitHub Deployment env name
  local bump src="bump"; bump=$(latest_bump "$2" "$3")
  if [[ -z "$bump" ]]; then
    local env
    for env in "$4" "$(tr "[:lower:]" "[:upper:]" <<<"${4:0:1}")${4:1}"; do bump=$(latest_deployment "$env"); [[ -n "$bump" ]] && break; done
    src="GitHub deployment"
  fi
  if [[ -z "$bump" ]]; then echo "$1: unknown (no '$bump_prefix $3' commit on $2 and no successful '$4' GitHub deployment)"; return; fi
  local sha="${merge_sha:-$head_sha}"
  if contains_sha "$bump" "$sha" || { [[ -n "$merge_sha" ]] && contains_sha "$bump" "$head_sha"; }; then
    echo "$1: YES (in $src ${bump:0:9}, by SHA)"
  else
    local log hit; log=$(recent_subjects "$bump")
    if contains_subjects "$log"; then
      echo "$1: LIKELY (all PR commit subjects found before $src ${bump:0:9}; cherry-picked)"
    elif hit=$(mentions_ticket "$log") && [[ -n "$hit" ]]; then
      echo "$1: LIKELY (overlay commit before $src ${bump:0:9}: \"$hit\")"
    else
      echo "$1: NO"
    fi
  fi
}

# Docs-only PRs (ADRs, specs, markdown) never deploy; say so instead of "unknown", which
# would otherwise make wait_for_deploy.sh spin until its timeout.
if jq -e '(.files | length) > 0 and all(.files[].path; test("(\\.md$|^docs/|^spec/|/adr/)"; "i"))' <<<"$pr_json" >/dev/null; then
  echo "PR: $full#$pr  state=$state  (docs only)"
  echo "staging: n/a (docs only)"; echo "production: n/a (docs only)"; exit 0
fi

echo "PR: $full#$pr  state=$state  base=$(jq -r .baseRefName <<<"$pr_json")  merged=$(jq -r '.mergedAt // "-"' <<<"$pr_json")"
staging_env="${STAGING_DEPLOY_ENV:-staging}"
if { [[ -n "$staging_branch" ]] && gh api "repos/$full/branches/$staging_branch" --silent 2>/dev/null; } \
   || [[ -n "$(gh api "repos/$full/deployments?environment=$staging_env&per_page=1" --jq '.[0].id // empty' 2>/dev/null)" ]]; then
  check_env "staging" "${staging_branch:-$prod_branch}" "${STAGING_BUMP_ENV:-staging}" "$staging_env"
else
  echo "staging: n/a (no staging branch or deployments)"
fi
check_env "production" "$prod_branch" "${PROD_BUMP_ENV:-prod}" "${PROD_DEPLOY_ENV:-production}"
