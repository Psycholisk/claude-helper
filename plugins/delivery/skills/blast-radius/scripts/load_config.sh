# Sourced by the delivery scripts. Loads ~/.claude/delivery-skills/config.env, then
# plugin-options.env (the plugin's /config options, written by the SessionStart hook), so an
# option that is set wins over the same key in config.env.
# A value still shaped like <...> is an unfilled template placeholder and is cleared.
delivery_cfg_dir="${DELIVERY_SKILLS_HOME:-$HOME/.claude/delivery-skills}"
for _f in "$delivery_cfg_dir/config.env" "$delivery_cfg_dir/plugin-options.env"; do
  # shellcheck source=/dev/null
  [[ -f "$_f" ]] && source "$_f"
done
for _k in TRACKER TICKET_PREFIX TICKET_DONE_STATE TICKET_QA_STATE GH_ORG CODE_ROOT REPO_GLOBS SLOW_REPOS \
          PROD_BRANCH STAGING_BRANCH BUMP_PATH BUMP_PREFIX PROD_BUMP_ENV STAGING_BUMP_ENV PROD_DEPLOY_ENV \
          STAGING_DEPLOY_ENV TIMEZONE WORK_DAYS CHECK_TIME OWNER_NAME CHAT_TOOL OWNER_CHAT_ID TODO_APP TODO_PROJECT; do
  [[ "${!_k-}" == \<*\> ]] && printf -v "$_k" '%s' ""
done
unset _f _k
