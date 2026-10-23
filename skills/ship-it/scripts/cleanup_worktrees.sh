#!/usr/bin/env bash
# Find (and optionally remove) the local worktrees left behind by a shipped ticket.
#
# Usage: cleanup_worktrees.sh <ticket-id> [--apply]
#   dry run by default: prints one line per worktree with the planned action.
#
# Reads CODE_ROOT, REPO_GLOBS and TICKET_PREFIX from ~/.claude/delivery-skills/config.env.
#
# A worktree belongs to the ticket when its branch or directory contains the ticket id
# (sc-30663, sc30663, sc-30663-...), which also catches per-ticket staging-prep worktrees
# like `_staging-sc29034-28927`. Shared generic ones (`_staging-merge`) never match and
# are left alone: other sessions use them.
#
# Safety rules (why: other Claude sessions share these clones and worktrees):
#   - REMOVE only if the worktree is clean (no uncommitted or untracked files) AND its
#     branch's PR is merged (or it is a detached staging-prep worktree for this ticket).
#   - SKIP-DIRTY / SKIP-UNMERGED otherwise — never --force.
#   - Local branch deleted with `git branch -d` (refuses if not merged into its upstream
#     history — then reported, not forced). Remote branch deleted only if it still exists
#     and the PR is merged.
set -uo pipefail

cfg="${DELIVERY_SKILLS_HOME:-$HOME/.claude/delivery-skills}/config.env"
# shellcheck source=/dev/null
[[ -f "$cfg" ]] && source "$cfg"
root="${CODE_ROOT:-$HOME/code}"
globs="${REPO_GLOBS:-*}"; [[ "$globs" == \<* ]] && globs="*"
prefix="${TICKET_PREFIX:-}"; [[ "$prefix" == \<* ]] && prefix=""

id="${1:?usage: cleanup_worktrees.sh <ticket-id> [--apply]}"
shopt -s nocasematch; [[ -n "$prefix" && "$id" == "$prefix"* ]] && id="${id:${#prefix}}"; shopt -u nocasematch
apply=0; [[ "${2:-}" == --apply ]] && apply=1
# "sc-" matches sc-123 and sc123; with no prefix, the bare number must stand alone
if [[ -n "$prefix" ]]; then pat="${prefix%-}-?${id}([^0-9]|$)"; else pat="(^|[^0-9])${id}([^0-9]|$)"; fi
label="${prefix}${id}"
found=0

repos() { local g; for g in $globs; do printf '%s\n' "$root"/$g; done; }

while IFS= read -r main; do
  [[ -d "$main/.git" ]] || continue
  slug=$(git -C "$main" remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]+##; s#\.git$##')
  touched=0
  while IFS=$'\t' read -r path branch; do
    [[ "$path" == "$main" ]] && continue
    grep -qiE "$pat" <<<"$path $branch" || continue
    touched=1; found=1
    if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
      echo "SKIP-DIRTY     $path [$branch] — uncommitted changes"; continue
    fi
    merged=""
    if [[ "$branch" != "(detached)" ]]; then
      merged=$(gh pr list --repo "$slug" --head "$branch" --state merged --json number --jq '.[0].number // empty' 2>/dev/null)
      if [[ -z "$merged" ]]; then echo "SKIP-UNMERGED  $path [$branch] — no merged PR"; continue; fi
    fi
    if (( apply )); then
      git -C "$main" worktree remove "$path" && echo "REMOVED        $path" || { echo "FAILED         $path"; continue; }
      if [[ "$branch" != "(detached)" ]]; then
        git -C "$main" branch -d "$branch" >/dev/null 2>&1 && echo "  local branch deleted: $branch" \
          || echo "  local branch kept (git refused -d): $branch"
        if git -C "$main" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
          git -C "$main" push -q origin --delete "$branch" && echo "  remote branch deleted: $branch"
        fi
      fi
    else
      echo "WOULD-REMOVE   $path [$branch]${merged:+ (PR #$merged merged)}"
    fi
  done < <(git -C "$main" worktree list --porcelain | awk '
      /^worktree /{p=substr($0,10)} /^branch /{b=substr($0,8); sub("refs/heads/","",b)}
      /^detached/{b="(detached)"} /^$/{if(p!="")print p "\t" b; p=""; b=""}
      END{if(p!="")print p "\t" b}')
  (( apply && touched )) && git -C "$main" worktree prune
done < <(repos)
if (( ! found )); then
  echo "No worktrees found for $label."
  # leftover branches without a worktree are still worth knowing about
  while IFS= read -r main; do
    [[ -d "$main/.git" ]] || continue
    git -C "$main" for-each-ref --format='%(refname:short)' refs/heads | grep -iE "$pat" \
      | sed "s|^|  local branch left in $(basename "$main"): |"
  done < <(repos)
fi
exit 0
