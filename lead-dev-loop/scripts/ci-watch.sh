#!/bin/sh
# Watch GitHub CI for a repository and print one line per event worth acting on, then keep watching.
#
#   CI_WATCH_REPO=owner/name sh ci-watch.sh     # forever; Ctrl-C to stop
#   CI_WATCH_REPO=owner/name CI_WATCH_STATE=~/.cache/ci-watch sh ci-watch.sh
#
# Lines it prints:
#   PR-FAIL #n <sha>: <check>     a check on a PR's head failed (the moment it fails)
#   READY #n <sha>                every check on a PR's head passed or was skipped, the ones main
#                                 requires among them (once per head)
#   CONFLICT #n <sha>             a PR's head no longer merges into its base (once per head)
#   MAIN-OK run <id>              a run on main succeeded
#   CANCELLED-MAIN mid-run <id>   a main run was cancelled after a job had started
#   FAIL <conclusion> ...         any other run finished badly, of any workflow (it names which):
#                                 a failure on the default branch is news whichever workflow had
#                                 it, so a workflow that cannot succeed yet is gated to skip there,
#                                 not ignored here
#   STALL: ...                    runs queued and no runner busy for 15 minutes
#
# Draft PRs are left out: CI skips every job on a draft, which would read as READY.
#
# Meant to be read by a person or an agent's line monitor, so it prints nothing else. It polls
# `gh` every 30 s and needs only `gh` (logged in) and a POSIX sh: every filter is `gh --jq`.
#
# Environment:
#   CI_WATCH_REPO   owner/name to watch (required)
#   CI_WATCH_BRANCH the default branch (default main); its ruleset's required checks gate READY
#   CI_WATCH_STATE  directory for what it has already reported (default $TMPDIR/ci-watch-$(echo "$R" | tr / -)),
#                   so a restarted watcher does not repeat itself. On its first start it marks
#                   every run already finished as seen.
#
# Single instance per state directory: the newest start writes its token to `owner` and any
# older watcher sharing the directory exits at its next poll. (Two watchers sharing the state
# each marked the other's events seen.)
R=${CI_WATCH_REPO:?set CI_WATCH_REPO=owner/name}
B=${CI_WATCH_BRANCH:-main}
D=${CI_WATCH_STATE:-${TMPDIR:-/tmp}/ci-watch-$(echo "$R" | tr / -)}
mkdir -p "$D" || exit 1
touch "$D/runs" "$D/ready" "$D/prfail" "$D/conflict"
if [ ! -s "$D/runs" ]; then
  gh run list -R "$R" -L 100 --json databaseId,status \
    --jq '.[]|select(.status=="completed")|.databaseId' > "$D/runs" 2>/dev/null
fi
idle_since=""
token="$$-$(date +%s)"
echo "$token" > "$D/owner"
while true; do
  [ "$(cat "$D/owner" 2>/dev/null)" = "$token" ] || exit 0
  gh run list -R "$R" -L 40 --json databaseId,status,conclusion,headBranch,event,workflowName \
    --jq '.[]|"\(.databaseId) \(.status) \(.conclusion) \(.headBranch) \(.event) \(.workflowName)"' \
    > "$D/now" 2>/dev/null || { sleep 60; continue; }
  while read -r id st concl br ev wf; do
    [ "$st" = completed ] || continue
    grep -qx "$id" "$D/runs" && continue
    echo "$id" >> "$D/runs"
    case "$concl" in
      success) [ "$br" = "$B" ] && echo "MAIN-OK run $id" ;;
      # A draft's run, or the one a closed pull request starts to cancel its own, skips every job.
      skipped) ;;
      # A main run superseded while still waiting is by design (the newest one tests it all);
      # one cancelled after a job had begun means main is being cancelled mid-run.
      cancelled)
        if [ "$br" = "$B" ]; then
          ran=$(gh run view -R "$R" "$id" --json jobs \
            --jq '[.jobs[]|select((.steps|length)>0)]|length' 2>/dev/null || echo 0)
          [ "$ran" != 0 ] && echo "CANCELLED-MAIN mid-run $id"
        fi ;;
      *) echo "FAIL $concl workflow=\"$wf\" branch=$br event=$ev run=$id https://github.com/$R/actions/runs/$id" ;;
    esac
  done < "$D/now"
  # A failed check is news the moment it fails, not when its run's other jobs finish: a run's
  # status stays "in progress" while a sibling job queues, which can hide a failure for an hour.
  gh pr list -R "$R" --json number,headRefOid,statusCheckRollup,isDraft \
    --jq '.[]|select(.isDraft|not)|. as $p|.statusCheckRollup[]|select(.conclusion=="FAILURE")|"\($p.number) \($p.headRefOid[0:7]) \(.name|.[0:40])"' \
    2>/dev/null |
  while read -r n sha name; do
    key="$n $sha $name"
    grep -qxF "$key" "$D/prfail" && continue
    echo "$key" >> "$D/prfail"
    echo "PR-FAIL #$n $sha: $name"
  done
  # Ready means every check main requires is there and green, and nothing else is pending or
  # failed. The required names come from main's rules each poll, not from here: a run creates a
  # job's check only once the job is queued, so "all present checks green" is briefly true with
  # the last job (the required `ci`, which waits for the rest) not created yet.
  req=$(gh api "repos/$R/rules/branches/$B" \
    --jq '[.[]|select(.type=="required_status_checks")|.parameters.required_status_checks[].context]|tojson' \
    2>/dev/null) || req='[]'
  [ -n "$req" ] || req='[]'
  gh pr list -R "$R" --json number,headRefOid,statusCheckRollup,isDraft \
    --jq "$req"' as $req|.[]|select(.isDraft|not)|select((.statusCheckRollup|length)>=2 and all(.statusCheckRollup[]; .conclusion=="SUCCESS" or .conclusion=="SKIPPED" or .conclusion=="NEUTRAL") and ([.statusCheckRollup[].name] as $have|all($req[]; . as $n|$have|index([$n]))))|"\(.number) \(.headRefOid[0:7])"' \
    2>/dev/null |
  while read -r n sha; do
    grep -qx "$n $sha" "$D/ready" && continue
    echo "$n $sha" >> "$D/ready"
    echo "READY #$n $sha"
  done
  gh pr list -R "$R" --json number,headRefOid,mergeable,isDraft \
    --jq '.[]|select((.isDraft|not) and .mergeable=="CONFLICTING")|"\(.number) \(.headRefOid[0:7])"' \
    2>/dev/null |
  while read -r n sha; do
    grep -qx "$n $sha" "$D/conflict" && continue
    echo "$n $sha" >> "$D/conflict"
    echo "CONFLICT #$n $sha"
  done
  # A run reads "queued" while any job of it waits, even with another job running, so a stall
  # is judged by the runners: work waiting and no runner busy. A run can also read "pending" with
  # its first job queued: "queued" alone once missed a run stuck that way for over an hour.
  busy=$(gh api "repos/$R/actions/runners" --jq '[.runners[]|select(.busy)]|length' 2>/dev/null || echo 1)
  if grep -qE " (queued|pending) " "$D/now" && [ "$busy" = 0 ]; then
    [ -z "$idle_since" ] && idle_since=$(date +%s)
    if [ $(( $(date +%s) - idle_since )) -ge 900 ]; then
      echo "STALL: runs queued, none running for 15 min"
      idle_since=$(date +%s)
    fi
  else
    idle_since=""
  fi
  sleep 30
done
