#!/usr/bin/env bash
# SessionStart hook: make the plugin's options (set when the plugin is enabled, editable in
# /config) visible to the skills' scripts, and seed the config folder on first use.
#
# Why a file: Claude Code exports options as CLAUDE_PLUGIN_OPTION_<KEY> only to hook
# processes, not to the Bash commands the skills run. So each session we write them to
# plugin-options.env, which load_config.sh sources after config.env (options win when set).
#
# The folder lives in ~/.claude/delivery-skills/, not ${CLAUDE_PLUGIN_DATA}, on purpose: the
# service map, channels and QA capabilities registry are built up over months, and the plugin
# data folder is deleted when the plugin is uninstalled.
#
# Must print nothing: SessionStart stdout is injected into every session's context.
set -uo pipefail

dir="${DELIVERY_SKILLS_HOME:-$HOME/.claude/delivery-skills}"
skills="${CLAUDE_PLUGIN_ROOT:?}/skills"
mkdir -p "$dir" || exit 0

# seed templates without ever overwriting the user's copies
seed() { [[ -e "$dir/$2" ]] || cp "$skills/$1" "$dir/$2"; }
seed blast-radius/templates/config.env config.env
seed blast-radius/templates/service-map.md service-map.md
seed ship-it/templates/channels.md channels.md
seed qa-it/templates/capabilities.md capabilities.md

keys="TRACKER TICKET_PREFIX TICKET_DONE_STATE GH_ORG CODE_ROOT REPO_GLOBS PROD_BRANCH STAGING_BRANCH
      BUMP_PATH TIMEZONE OWNER_NAME CHAT_TOOL OWNER_CHAT_ID TODO_APP TODO_PROJECT"
tmp=$(mktemp "$dir/.plugin-options.XXXXXX") || exit 0
{
  echo "# Written by the delivery plugin's SessionStart hook from its options (/config)."
  echo "# Don't edit: change the option instead. Sourced after config.env, so set options win."
  for k in $keys; do
    var="CLAUDE_PLUGIN_OPTION_$k"
    # unset vs empty for a blank option isn't documented, so treat both as "not set"
    v="${!var-}"
    [[ -n "$v" ]] || continue
    [[ "$k" == CODE_ROOT && "$v" == "~"* ]] && v="$HOME${v:1}"
    # single-quote for shell, escaping embedded single quotes
    printf "%s='%s'\n" "$k" "${v//\'/\'\\\'\'}"
  done
} >"$tmp" && mv "$tmp" "$dir/plugin-options.env"
exit 0
