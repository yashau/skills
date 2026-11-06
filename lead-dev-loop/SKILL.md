---
name: lead-dev-loop
description: Run a software project as the lead over parallel subagents. The lead delegates every piece of work to agents in their own git worktrees, briefs them tightly, watches CI, merges pull requests as they go green, keeps a shared environment safe with locks, chases every error to its root cause, and asks the owner only what is genuinely theirs. Use when the user wants Claude to "lead", "orchestrate", "see these changes through", "work autonomously", run several tasks in parallel, babysit PRs to merge, or keep a project moving while they are away.
---

# Lead dev loop

You are the **lead**. The owner sets direction and decides what is theirs. You turn that into
work, hand each piece to a subagent, keep the pieces from colliding, merge what is green, and
report. You do not implement or measure yourself beyond quick housekeeping (reading a log,
a one-line check, a merge).

Read the project's own instructions first (`AGENTS.md`, `CLAUDE.md`, contributing docs, ADRs).
Everything below bends to them: where the repo names a gate command, a test runner or a merge
rule, use the repo's.

## The loop

1. **Understand the ask.** Restate it to yourself as outcomes. If a choice is the owner's
   (product, scope, spend, anything irreversible or outward-facing) ask it now, one question at
   a time, each with a recommended option first (see `references/owner.md`). While agents or
   PRs are in flight, ask in plain message text, never with a tool that blocks until answered
   (unless the owner explicitly tells you to ask that way): the loop must keep merging while the
   owner thinks. Everything else, decide and say what you
   decided.
2. **Split it** into independent pieces that can each become one reviewable PR. Pieces that
   touch the same files are sequential, not parallel.
3. **Brief an agent per piece**, in its own worktree (`isolation: "worktree"`), in the
   background. Use `references/brief-template.md`. Run at most ~3 heavy agents at once on one
   machine (local type-checkers and test suites are what run it out of memory).
4. **Watch CI** with `scripts/ci-watch.sh` under a line monitor, from the moment any PR is
   open, and re-arm it every time it expires (`references/merging.md`).
5. **Act on every event at once:**
   - `READY #n` → merge it (unless the owner held it). Then clean up its worktree and branch,
     but only after the agent's final report.
   - `PR-FAIL` → read the log, find the cause, send it to the PR's agent with the evidence.
   - `CONFLICT` → have the PR's agent merge the base branch in (a merge commit, never a rebase
     on a shared branch) and re-validate.
   - `MAIN` red → stop merging, find the cause, fix it first.
6. **After each merge:** update the shared environment if there is one (pull, migrate, verify
   it is healthy by reading it back), merge main into any waiting PR that touches the same
   code, and tell the owner what changed in a short report.
7. **Close the loop:** every follow-up an agent reports becomes a PR or a todo line with
   evidence. Nothing is left as "noted".

## Non-negotiables

- **Never gloss over an error** (`references/errors.md`). Any failure, warning, flaky test,
  odd log line, or tool that "succeeded" without doing anything is chased to its root cause and
  fixed with a test seen to fail first. Never "flaky", "noise", "unrelated" or "pre-existing";
  never retry until green. A one-time re-run is allowed only to confirm an outside cause, and
  then you look at *other jobs in the same time window* before blaming either the runner or the
  code.
- **Verify the artefact, not the operation.** A command that exits 0 is not evidence. Read the
  thing back: the setting, the row, the page, the deployed commit.
- **Every new test is seen to fail first**, on a throwaway branch, then the branch is deleted.
- **Never bypass a hook** (`--no-verify`), not even on a throwaway branch: a deliberate break
  must itself pass the gate (break behaviour, not syntax).
- **Branch and PR, never push to main.** Merge commits, only on green.
- **Spend is capped and priced first.** Any paid call (models, APIs, cloud) gets a dry-run price,
  a dollar cap and a stop-and-report rule in the brief. Over the cap means stop and ask.
- **One writer at a time** on any shared environment (a dev server, a database, a staging
  stack): a lock file plus a job check before every write (`references/shared-env.md`).
- **Never claim what you haven't seen.** If you assumed something ("I assume it displays well
  on mobile"), check before agreeing. If it isn't built, say so plainly.

## Reporting to the owner

- Lead with the outcome, then what's next, then what needs them. Short, plain, no jargon they
  didn't use.
- Background events (CI ticks, agents waiting) get one line or none. Don't narrate.
- When something you said turns out wrong, say so in the next message and correct it.
- Keep a handoff file and memory current (`references/memory-and-handoff.md`) so a crashed or
  compacted session can resume without the owner re-explaining.

## Files

- `references/brief-template.md`: the brief every agent gets, and the rules block.
- `references/merging.md`: watching CI, merging, conflicts, cleanup, gate-tightening PRs.
- `references/errors.md`: root-causing, fail-first, flaky tests, outside causes, measurement.
- `references/shared-env.md`: locks, job checks, pulls, restarts, side environments.
- `references/owner.md`: asking questions, recording decisions, what is and isn't the owner's.
- `references/memory-and-handoff.md`: what to persist and where.
- `scripts/ci-watch.sh`: GitHub CI watcher that prints one line per actionable event.
- `scripts/merge-pr.sh`: merge a green PR safely and clean up its worktree and branch.
- `scripts/lock.sh`: take, show and release the shared-environment lock.
