# Briefing an agent

A brief is the only context the agent has. Write it like a handover to a capable peer who has
never seen the project: the goal, what you already know or ruled out, where to look, the exact
scope, the checks it must pass, and what to report. Vague briefs come back confidently wrong.

## Shape

```
You work on <project> (<path>). Read <AGENTS.md / CLAUDE.md / the part's conventions> and
<the ADRs or docs this touches> first. Also read the common rules: <path to rules block>.

<Context: what happened, the evidence (log lines, run ids, file:line), what is ruled out.>

Task, on branch `<prefix>/<name>` from origin/main:
1. <Root cause first, if it's a bug: how to find it, the hypotheses to test, not assume.>
2. <The change, scoped: what it does and explicitly what it does NOT do.>
3. <Tests: what each proves; seen to fail first on `<branch>-failfirst`.>
4. <Docs that must change in the same PR.>
5. <Checks: gate under the lock, remote/full tests, e2e for UI, screenshots for layout.>
6. <Anything on a shared environment: "don't, I'll do it" or exact lock + job-check steps.>
Open the PR, check its body, report: the PR link, what changed, fail-first evidence, test
results, anything left open, any decision that is the owner's (with options).
```

## Rules block (keep it in one file and point every brief at it)

- Read the repo's instructions and follow them exactly. Cut the branch from the latest
  origin/main. Small commits, each passing the gate.
- **Never `--no-verify`**, not even on a throwaway branch: make the deliberate break pass the
  gate.
- **Every new test is seen to fail first**: commit the break on `<branch>-failfirst`, run the
  tests, watch them fail, delete the branch (local and remote).
- **Heavy local commands run under one shared lock**, one at a time across agents:
  `flock <gate.lock> <command>` (commits whose hook runs the gate, type-checks, builds, local
  test suites, local browsers). For `git commit` from a worktree guard that refuses `flock …
  git commit`: `exec 9><gate.lock>; flock 9; git commit …; flock -u 9`. Remote test runs need
  no lock. Don't spawn sub-agents.
- **No paid calls** unless the brief gives a price, a cap and a stop rule. If the work needs
  spend to finish, build it, stop, report the price.
- **Shared environment writes** need the lock and the job check first; never pull or restart
  it (the lead does).
- **Scratch** goes in `<scratch>/<branch>/` with a `progress.md` (time, step, result), so a hang
  is distinguishable from slow. Never write to `/tmp` if the machine's `/tmp` is RAM-backed.
- **Parallel PRs**: don't edit the shared todo file; list follow-ups as `Todo:` lines in the PR
  body. The lead applies them in one PR.
- **Greenfield** (if true): no redirects, compatibility shims or deprecation windows.
- **Errors are never glossed over**: any error, warning, flaky result or odd log line you see is
  root-caused and fixed with a test seen to fail first, in this PR if in scope, else reported
  with evidence for its own PR.
- **Owner decisions** (product choices, anything ambiguous in scope) are not yours: stop and
  report the question with options.
- Check the PR body after creating it (parallel agents have swapped bodies).
- Commit and PR footers as the repo or session requires. No model identifiers in commits or PRs.

## Tips

- **Give the hypothesis, not the conclusion**, and say "test, not assume". An agent handed your
  theory tends to confirm it.
- **Name the trap you already know about**: "the tool exits 0 when it skips a proposed type".
- **Ask for numbers**: before/after timings, prices, counts read back.
- **Resume, don't respawn.** Send follow-ups to the same agent (it keeps its context and
  worktree). A new agent starts from zero.
- **Rate-limited agents**: if agents stop on a usage limit, schedule a wake shortly after the
  reset and resume each with "continue where you left off".
