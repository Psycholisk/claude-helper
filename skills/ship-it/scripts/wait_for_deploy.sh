#!/usr/bin/env bash
# Block until every given PR is live in production, then exit. Built for a single
# background notification (Bash run_in_background), not a Monitor stream.
#
# Usage: wait_for_deploy.sh [--timeout-min N] <repo>#<pr> [<repo>#<pr> ...]
#   e.g. wait_for_deploy.sh billing#609 payments#93 admin-ui#25
#
# Exit codes (the caller decides what to do; every outcome prints a final summary):
#   0  all PRs live in production (YES or LIKELY per deploy_status.sh; docs-only PRs count as n/a)
#   1  timed out (default 45 min) — some PRs still not live
#   2  bad usage
# Polls every 60s; the GitHub API is the source, so keep the interval >= 30s.
set -uo pipefail

status_script="$HOME/.claude/skills/blast-radius/scripts/deploy_status.sh"
timeout_min=45
if [[ "${1:-}" == --timeout-min ]]; then timeout_min="${2:?}"; shift 2; fi
[[ $# -gt 0 ]] || { echo "usage: wait_for_deploy.sh [--timeout-min N] <repo>#<pr> ..." >&2; exit 2; }

deadline=$(( $(date +%s) + timeout_min * 60 ))
pending=("$@")
while :; do
  still=()
  for item in "${pending[@]}"; do
    repo="${item%%#*}"; pr="${item##*#}"
    line=$("$status_script" "$repo" "$pr" 2>/dev/null | grep '^production:' || echo "production: unknown")
    if [[ "$line" == "production: YES"* || "$line" == "production: LIKELY"* || "$line" == "production: n/a"* ]]; then
      echo "LIVE    $item — ${line#production: }"
    else
      still+=("$item")
    fi
  done
  pending=("${still[@]+"${still[@]}"}")
  [[ ${#pending[@]} -eq 0 ]] && { echo "ALL LIVE"; exit 0; }
  if (( $(date +%s) >= deadline )); then
    for item in "${pending[@]}"; do echo "PENDING $item"; done
    echo "TIMEOUT after ${timeout_min}m — ${#pending[@]} PR(s) not live"
    exit 1
  fi
  sleep 60
done
