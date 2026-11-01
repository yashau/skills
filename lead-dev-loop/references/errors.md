# Errors, tests and measurement

## The rule

Any error, warning, failed job, 5xx, traceback, flaky or unexpected test result, or odd log
line seen in tests, CI, a shared environment's logs or a measurement run is investigated to its
root cause and fixed, with a test seen to fail first: in the same PR if it is in scope,
otherwise in its own PR straight after. What cannot be fixed now goes in the todo file with its
evidence, and the report says so.

Never call it "flaky", "noise", "unrelated" or "pre-existing". Never retry until green, skip
it or silence it.

## Patterns that have paid off

- **"Flaky" is a symptom.** Repeat the one test 20 to 30 times with traces and screenshots kept
  somewhere that outlives the test machine, or printed into the log. Then read the
  application's own log for the failing run: a race in a test is often a real bug (concurrent
  first requests that each try to create the same row, and all but one get a 409).
- **A tool that succeeds without doing anything is a bug.** Exit 0 with nothing written, or a
  flag that silently does nothing in one state, gets fixed so it fails loudly, with a test.
- **Read back, don't trust output.** Re-run in dry-run mode after applying: it must say
  "nothing differs".
- **Warnings accumulate when the gate passes on them.** Find out why warnings don't fail the
  gate, fix the existing ones, then make warnings fail.
- **Something the model "fills to the cap"** (thinking, tokens) isn't fixed by a bigger cap:
  find what makes it expand.
- **Check the time window.** For an intermittent infrastructure-looking failure, list every
  job's errors across the last N runs and see whether they cluster in time.

## Fail first

1. Write the test.
2. On a throwaway branch `<branch>-failfirst`, break the behaviour the test is about (not the
   syntax: the break must pass the gate).
3. Run it; it must fail on the right assertion. A test failing for an unrelated reason (a
   missing column) doesn't count: fix that and re-run.
4. Delete the branch locally and on the remote.

A test that passes because there is nothing to find proves nothing.

## Measuring

- Derive expected values from the data; never type them.
- Price first (a dry run), cap it, stop over the cap.
- A run that shows an error is not a result. Fix it first.
- Synthetic scores don't predict real data. Measure on real samples and grade some by eye.
- Record spend in a ledger: time, what, forecast, actual, running total.
