# Memory and handoff

Sessions crash, run out of context and get compacted. The owner should never have to re-explain.

## Memory (persistent, across sessions)

One fact per file, with a short index. Keep:

- **Current hold:** what is merged, the shared environment's state (commit, migration), what is
  in flight and with which agent, what is waiting on the owner. Rewrite it at every milestone.
- **Owner decisions,** dated, with their words where it matters.
- **Workflow lessons** ("feedback"): each with **why** (the incident) and **how to apply**. Add
  one whenever you slip or the owner corrects you, e.g. "never chain the job check and the pull",
  "remove a worktree only after the agent's final report", "check other jobs in the same window
  before blaming the runner".
- **References:** where the tools, ledgers and scratch files live.

Don't store what the repo already records (code structure, git history). Update rather than
duplicate; delete what turns out wrong.

## Handoff file (in the repo root, untracked)

For the next session if this one dies mid-task:

- the owner's standing instruction for this stretch ("see these changes through");
- a status line at the top: merged through #n, environment at commit X, agents running;
- the in-flight list, each with its agent, worktree, and the exact next step;
- how the lead works here: the watcher command, the merge script, the lock and job check, the
  restart-window rule.

## Scratch

A session scratch directory for briefs, ledgers, reports, screenshots and logs. Name files by
task. Spend ledgers record time, forecast, actual and running total.
