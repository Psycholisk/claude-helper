#!/usr/bin/env bash
# Search every local clone for a pattern, on each repo's up-to-date default branch.
#
# Usage: grep_all_repos.sh [-f] [-a] <git-grep-args...>
#   e.g. grep_all_repos.sh -n -e 'account_blocked'
#        grep_all_repos.sh -f -n -i 'not_attempted_reason'   # -f: git fetch each repo first
#   -a: also search the slow repos listed in SLOW_REPOS (huge or legacy monoliths; only
#       include them when legacy callers matter)
#
# Reads CODE_ROOT, REPO_GLOBS and SLOW_REPOS from ~/.claude/delivery-skills/config.env.
#
# Why: blast radius crosses service lines (a field one service emits, another reads), and
# each repo has its own default branch (some use develop). Grepping origin/<default>
# instead of the working tree avoids stale or mid-edit checkouts and never touches the
# clones' checked-out state, which other sessions/worktrees share.
set -uo pipefail

cfg="${DELIVERY_SKILLS_HOME:-$HOME/.claude/delivery-skills}/config.env"
# shellcheck source=/dev/null
[[ -f "$cfg" ]] && source "$cfg"
root="${CODE_ROOT:-$HOME/code}"
globs="${REPO_GLOBS:-*}"; [[ "$globs" == \<* ]] && globs="*"
slow=" ${SLOW_REPOS:-} "
fetch=0; all=0
while [[ "${1:-}" == -f || "${1:-}" == -a ]]; do
  [[ "$1" == -f ]] && fetch=1 || all=1; shift
done
[[ $# -gt 0 ]] || { echo "usage: grep_all_repos.sh [-f] [-a] <git-grep-args...>" >&2; exit 2; }

for g in $globs; do
  for repo in "$root"/$g; do
    [[ -d "$repo/.git" ]] || continue
    name=$(basename "$repo")
    (( all )) || [[ "$slow" != *" $name "* ]] || continue
    (( fetch )) && git -C "$repo" fetch -q origin 2>/dev/null
    ref=$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) \
      || ref=$(git -C "$repo" rev-parse -q --verify origin/main >/dev/null && echo origin/main) \
      || continue
    # prefix each hit with the repo name; strip git grep's "<ref>:" prefix
    git -C "$repo" grep -I "$@" "$ref" -- 2>/dev/null | sed "s|^$ref:|$name ($ref): |"
  done
done
