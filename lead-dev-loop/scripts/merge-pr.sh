#!/usr/bin/env bash
# Merge a green PR exactly as tested, then remove its local worktree and branch.
#
#   merge-pr.sh <pr-number> [repo-dir]            # repo-dir defaults to the current directory
#   MERGE_ADMIN=1 merge-pr.sh <n>                 # pass --admin (a maintainer bypassing a review rule)
#   MERGE_KEEP_WORKTREE=1 merge-pr.sh <n>         # merge only; the agent still has work after merge
#
# Refuses when a non-docs file the PR changes has also changed on the base branch since the PR's
# merge base: its green run was against an older base, so have the PR merge the base in and
# re-run CI first. Merges with a merge commit, pinned to the head that was green
# (--match-head-commit), so a push after READY can't slip in untested.
#
# Cleanup only after the agent's FINAL report: removing a worktree an agent still uses makes it
# impossible to resume. The Agent tool only removes worktrees with no changes, so merged ones
# pile up unless removed here.
set -euo pipefail
N=${1:?usage: merge-pr.sh <pr-number> [repo-dir]}
cd "${2:-.}"
git fetch -q origin
base=$(gh pr view "$N" --json baseRefName --jq .baseRefName)
br=$(gh pr view "$N" --json headRefName --jq .headRefName)
sha=$(gh pr view "$N" --json headRefOid --jq .headRefOid)
b=origin/$br
mb=$(git merge-base "origin/$base" "$b")
overlap=$(comm -12 <(git diff --name-only "origin/$base...$b" | sort) \
                   <(git diff --name-only "$mb" "origin/$base" | sort) | grep -v '^docs/' || true)
if [ -n "$overlap" ]; then
  echo "REFUSED #$N: changed on $base since this PR's base, merge $base in and re-run CI:"
  echo "$overlap" | sed 's/^/  /'
  exit 1
fi
git merge-tree --write-tree "origin/$base" "$b" >/dev/null || { echo "REFUSED #$N: conflicts with $base"; exit 1; }
gh pr merge "$N" --merge ${MERGE_ADMIN:+--admin} --match-head-commit "$sha"
[ "$(gh pr view "$N" --json state --jq .state)" = MERGED ] || { echo "NOT MERGED #$N"; exit 1; }
echo "MERGED #$N ($sha)"
[ -n "${MERGE_KEEP_WORKTREE:-}" ] && exit 0
wt=$(git worktree list --porcelain | awk -v r="refs/heads/$br" '/^worktree /{p=$2} $0=="branch "r{print p}')
if [ -n "$wt" ]; then
  git worktree remove -f -f "$wt" && echo "REMOVED $wt"
  git branch -q -D "worktree-$(basename "$wt")" 2>/dev/null || true
fi
git branch -q -D "$br" 2>/dev/null && echo "DELETED $br" || true
git worktree prune
