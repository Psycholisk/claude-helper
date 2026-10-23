#!/usr/bin/env bash
# Print the effective delivery config (config.env + plugin options) and what's still missing.
# The skills run this as their first-run check.
#
# Usage: config_status.sh
# Output: the config folder and its files, then one "KEY=value" or "KEY MISSING" line per key.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/load_config.sh"

echo "folder: $delivery_cfg_dir"
for f in config.env plugin-options.env service-map.md channels.md capabilities.md qa-it.env; do
  [[ -e "$delivery_cfg_dir/$f" ]] && echo "  have $f" || echo "  no   $f"
done
# keys that may legitimately be empty
optional=" SLOW_REPOS STAGING_BRANCH BUMP_PATH OWNER_CHAT_ID TODO_PROJECT TICKET_QA_STATE "
for k in TRACKER TICKET_PREFIX TICKET_DONE_STATE TICKET_QA_STATE GH_ORG CODE_ROOT REPO_GLOBS SLOW_REPOS \
         PROD_BRANCH STAGING_BRANCH BUMP_PATH BUMP_PREFIX TIMEZONE WORK_DAYS CHECK_TIME \
         OWNER_NAME CHAT_TOOL OWNER_CHAT_ID TODO_APP TODO_PROJECT; do
  v="${!k-}"
  if [[ -n "$v" ]]; then echo "$k=$v"
  elif [[ "$optional" == *" $k "* ]]; then echo "$k=(empty, optional)"
  else echo "$k MISSING"; fi
done
