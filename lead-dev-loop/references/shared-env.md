# A shared environment

Any environment more than one agent can change (a dev server, a staging database, a shared
checkout) gets one writer at a time.

## The lock

A plain file, created atomically, holding who and why:

```
sh <skill>/scripts/lock.sh take "<agent or task>: <what>"   # fails if held
sh <skill>/scripts/lock.sh show
sh <skill>/scripts/lock.sh release
```

- Take it only to write. **Waiting is not writing**: an agent waiting on a slow batch job
  releases the lock and takes it again for its next write.
- Agents queue for it (a small `until` loop in the background). Whoever gets it first goes.

## The job check

Before any write, pull or restart, list what is running on the environment (long scripts,
evaluations, imports) with a process pattern, as **its own command**, and read it. Never chain
`check && pull`: a check that prints something must stop you.

## Pulls and restarts (the lead's job)

1. Lock free, job check clean.
2. Pull or redeploy.
3. A brief 502 or connection error straight after is the restart window: poll the health
   endpoint until it answers.
4. Read back: the commit it is on, migrations at head, every service running, the specific
   thing the change was about.
5. Release the lock.

An image change needs a full down and up, not a pull. Schedule it when nothing is running.

## Side environments

A second copy for trying a branch against real data (a "side stack") is one shared checkout:
only the agent you assign may bring it up, and bringing it up on a different branch may reset
its data.

## Permissions

Agents act on the environment as the person or service account the owner allows, through the
same audited paths a person would use (the API or UI, not raw SQL). If an agent needs a
permission it lacks, it says so; widening anyone's permissions is reported to the owner.
