# Watching CI and merging

## Watch

Run `scripts/ci-watch.sh` under a line monitor as soon as any PR is open:

```
CI_WATCH_REPO=<owner/repo> CI_WATCH_STATE=<state dir> sh <skill>/scripts/ci-watch.sh
```

with the monitor's longest timeout, and **re-arm it on every expiry** while any PR or agent is
in flight. GitHub's own notifications are not enough to wake you. When nothing is open, leave it
off and re-arm when the next PR opens.

Events: `READY #n sha`, `PR-FAIL #n sha: check`, `CONFLICT #n sha`, `MAIN-OK run id`,
`FAIL …`, `CANCELLED-MAIN …`, `STALL: …`. Drafts are ignored (CI skips them, which would read as
READY).

## Merge

- Merge on `READY` without asking, unless the owner held the PR or its agent said it is waiting
  on something (e.g. "description to follow once validated"). Read the PR body first.
- Merge commits only. Use `--match-head-commit <full sha>` so you merge exactly what was green.
- `scripts/merge-pr.sh <n>` refuses when non-docs files changed on main since the branch's base
  overlap the PR's files (a green run against an old base proves less), merges, and removes
  the worktree and branch.
- **Use plain `gh pr merge` instead when the agent still has work after merge** (a deploy step,
  an apply, a follow-up PR from the same worktree). Removing its worktree makes it impossible
  to resume. Clean up after its final report.
- A PR that is a deliberate fail-first ("do not merge") is never merged; its agent closes it.

## After a merge

- Pull or redeploy the shared environment if the change affects it (`shared-env.md`), and
  verify by reading back: the commit it is on, migrations at head, health endpoints, the
  setting or row the change was about.
- **Branches are not re-run against a newer main.** Merge main into any waiting PR that touches
  the same code.
- **A PR that tightens the gate** (a new lint rule, a new check) makes every open PR stale: each
  must merge main and re-run before it merges, or main goes red.
- Watch main's run after the merge. A red main is the top priority.

## Conflicts

- Have the PR's agent merge origin/main in with a merge commit; never rebase or force-push a
  shared branch. Regenerate lockfiles and generated files with the repo's tooling, never by
  hand.
- Shared bookkeeping files (todo lists, changelogs) cause most conflicts with parallel agents:
  keep them out of feature PRs and apply them in one PR.
- Migrations: after a merge, check there is still a single migration head.

## CI red

1. Read the failing job's log. Get to the first real error.
2. If it's in code the PR touches → back to its agent with the evidence.
3. If it looks external (network, a mirror, the runner), **check other jobs in the same time
   window** before deciding. Same failure elsewhere before any test ran → external; one re-run
   to confirm, and report it to whoever owns the infrastructure with run ids and timings.
   Same shard failing twice after a test re-shuffle → suspect the moved tests first.
4. A by-product step (an artifact upload, a timing record) should report its failure, not fail
   a job whose tests passed. Fix that alongside the root cause, with the reason in a comment.
5. Never skip, disable or quarantine a test to get green.
