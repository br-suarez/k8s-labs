# Lab 13.04 — Locks, and a stuck one

**CORE · 45 min**

## Context

Do the break-fix first. This lab builds the correct setup and then makes you
recover from a stuck lock without causing the damage the break-fix describes.

## The problem

### Part 1 — remote state with locking

Move state to a remote backend with locking. Locally, MinIO or a GCS bucket both
work; the mechanism matters more than the provider.

1. Where is the lock actually held? Is it the same object as the state?
2. What information does the lock record contain? Read one.

### Part 2 — cause a real collision

Two terminals:

```bash
# Terminal 1 — a slow apply
terraform apply -auto-approve

# Terminal 2 — immediately
terraform apply -auto-approve
```

3. What does terminal 2 report? Read the whole message.
4. Is that a failure? Justify your answer.

### Part 3 — the wrong fix, in a scratch workspace

Reproduce the break-fix mechanism so you have seen it:

```bash
terraform apply -auto-approve -lock=false &
terraform apply -auto-approve -lock=false &
wait
terraform state list | wc -l
# compare against what actually exists
```

5. How many resources exist? How many are in the state? Explain the gap.
6. Run `plan`. What does it propose, and what happens if you apply it?

Use a scratch workspace with disposable resources. This is destructive by design.

### Part 4 — a genuinely stuck lock

```bash
terraform apply -auto-approve &
APPLY_PID=$!
sleep 3
kill -9 $APPLY_PID        # simulate a runner dying mid-apply
terraform plan            # lock is still held
```

7. What does the error say? Which fields help you decide what to do?
8. How do you confirm the holder is really gone before unlocking?
9. Unlock it and verify the state is consistent afterwards.

Question 8 is the whole lab: `force-unlock` is safe **only** when you have
established the holder is dead. The lock info gives you who, where and when.

### Part 5 — the right fix in CI

10. Add `concurrency` to the infrastructure workflow. Why must
    `cancel-in-progress` be `false` here, and why is the reason different from
    the application pipeline in module 09?
11. Use `-lock-timeout` instead of failing immediately. What value, and why?
12. Write the CI check that refuses to merge if `-lock=false` appears anywhere.

## Expected outcome

Remote state with locking, a real collision observed, the damage of `-lock=false`
reproduced in a scratch workspace, a stuck lock diagnosed and cleared safely, and
three CI protections in place.

## Staged hints

<details><summary>Hint 1 — question 10</summary>

In module 09, cancelling a build wastes minutes. Here, cancelling an `apply`
mid-flight leaves resources created and not recorded — you manufacture orphans.
The cost of cancellation is qualitatively different, which is why the same flag
takes the opposite value.
</details>

<details><summary>Hint 2 — question 8</summary>

The lock records the operation, the user, the hostname and the timestamp. Check
whether that CI run is still active, or whether that host still exists. A lock
from three days ago on a runner that no longer exists is safe to clear; one from
40 seconds ago probably is not.
</details>
