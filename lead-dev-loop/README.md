# lead-dev-loop

A Claude Code skill for running a project as the lead over parallel subagents: delegate every
piece of work to an agent in its own worktree, brief it tightly, watch CI, merge on green, keep a
shared environment safe, chase every error to its root cause, and ask the owner only what is
theirs. Distilled from lead sessions on a large, complex project, with nothing project-specific
left in.

## Install

Skills are found under a `skills/` directory in the Claude config dir (personal) or a repo's
`.claude/skills/` (per project). Link it rather than copy it, so edits here apply everywhere:

```
ln -s /home/yashau/skills/lead-dev-loop ~/.claude-personal/skills/lead-dev-loop   # this machine's config dir
# or, for one repository:
ln -s /home/yashau/skills/lead-dev-loop <repo>/.claude/skills/lead-dev-loop
```

Then ask for it by name (`/lead-dev-loop`) or say "lead this", "see these changes through",
"run these in parallel and merge them as they go green".

## Contents

| File | What |
|---|---|
| `SKILL.md` | The loop, the non-negotiables, how to report |
| `references/brief-template.md` | The brief every agent gets, and the shared rules block |
| `references/merging.md` | Watching CI, merging, conflicts, cleanup, CI red |
| `references/errors.md` | Root-causing, fail-first tests, flaky tests, measuring |
| `references/shared-env.md` | Locks, job checks, pulls and restarts, side environments |
| `references/owner.md` | What is the owner's, asking, recording decisions |
| `references/memory-and-handoff.md` | What to persist so a crashed session resumes |
| `scripts/ci-watch.sh` | `CI_WATCH_REPO=owner/name sh ci-watch.sh`: one line per READY / PR-FAIL / CONFLICT / MAIN-OK / FAIL / STALL |
| `scripts/merge-pr.sh` | `merge-pr.sh <n>`: merge exactly the green head, refuse a stale base, clean up the worktree |
| `scripts/lock.sh` | `lock.sh take|wait|show|release`: one writer at a time on a shared environment |

The scripts need `gh` (logged in), `git` and a POSIX shell.

## Per project

The skill defers to the repo's own instructions. Before the first session in a new repo, write
down (in its `AGENTS.md`/`CLAUDE.md`, or tell the lead):

- the gate command (lint, types, format) and whether hooks run it;
- how to run the full tests remotely or locally, and how long they take;
- the merge rule (required checks, merge commits, who may bypass review);
- the shared environment, if any: how to pull it, its health endpoint, the job-check pattern;
- where scratch files go, and whether `/tmp` is RAM-backed.
