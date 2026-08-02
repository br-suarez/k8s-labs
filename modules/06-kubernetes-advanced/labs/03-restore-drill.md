# Lab 06.03 — The restore drill

**CORE · 55 min.** The most important lab in this module.

## Context

You are going to build a backup system that cannot lie, and then prove it by
destroying the database and bringing it back.

Do the **break-fix first** if you have not. Building the correct version is much
more meaningful once you have seen six months of green reporting nothing.

## The problem

### Part 1 — back up

Write `platform/scripts/backup.sh` and a `CronJob` in `batch/v1` that:

1. Dumps globals (`pg_dumpall --globals-only`) and the database (`pg_dump -Fc`)
   separately.
2. Fails loudly if either command fails — including inside a pipeline.
3. Verifies the dump is non-empty, above a plausible size floor, and readable
   by `pg_restore -l`.
4. Confirms the `results` table is present in the table of contents.
5. Writes atomically: `.part` then `mv`, so a partial file is never visible.
6. Purges old backups **only after** the new one is verified.
7. Passes `shellcheck`.

Requirement 6 is the one people miss: in a naive script, a broken backup deletes
the good ones.

### Part 2 — restore

Write `platform/scripts/restore-drill.sh` that, unattended:

1. Starts a throwaway Postgres.
2. Restores the most recent backup into it.
3. Runs an invariant query — row counts, a known check ID, referential integrity.
4. Fails loudly if anything is off.
5. Tears the throwaway instance down.
6. Emits `pulse_backup_last_verified_timestamp` for module 07 to alert on.

### Part 3 — the real drill, timed

```bash
# Confirm what you are about to lose
kubectl exec -n pulse postgres-0 -- psql -U pulse -d pulse \
  -c 'SELECT count(*) FROM results;'

# Destroy it. Start a timer now.
kubectl exec -n pulse postgres-0 -- psql -U pulse -d pulse \
  -c 'DROP TABLE results CASCADE;'
```

Restore it. **Time the whole thing**, from the moment you notice to a verified
working service.

Record in `NOTAS.md`:

| Measure | Value |
|---|---|
| Actual RPO (how much data was lost) | |
| Actual RTO (time to verified service) | |
| Steps that needed a human | |
| What you had to look up | |
| What went wrong the first time | |

That last row is the most valuable. Something always does.

### Part 4 — make the drill automatic

Schedule `restore-drill.sh` weekly. The point of automating it is that "do we
have backups?" stops being a question anyone has to remember to ask.

## Expected outcome

- A backup script that cannot report success without producing a restorable dump
- A restore drill that runs unattended
- Measured RPO and RTO from a real destruction
- A weekly CronJob and a metric to alert on

## Verification

```bash
./platform/scripts/restore-drill.sh && echo "restore verified"
shellcheck platform/scripts/*.sh
```

## Staged hints

<details><summary>Hint 1 — why -Fc rather than piping to gzip</summary>

Custom format is compressed internally, so there is no pipeline to lose an exit
code in. It also lets `pg_restore -l` inspect the contents without
decompressing, restore selected tables, and restore in parallel with `-j`. Piping
to `gzip` is what makes the break-fix possible in the first place.
</details>

<details><summary>Hint 2 — the invariant query</summary>

Row count alone is weak — a restore that silently truncates might still have
plausible counts. Better: a checksum over a stable column, plus a referential
check (`results` rows whose `check_id` has no matching `checks` row), plus the
most recent `observed_at` being within the expected window.
</details>

## Why this lab exists

`archive/sre-track/` has an SLO module and a toil-automation module. This is the
same discipline applied to the one operation nobody rehearses until the night
they need it.
