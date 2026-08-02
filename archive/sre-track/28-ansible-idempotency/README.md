# Refresher 28: Ansible — Idempotency

**Module:** 28 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

Two playbooks that reach the same end state on a clean host. One of them is
safe to run twice. Targets are Docker containers reached with the
`community.docker` connection plugin — `docker exec` instead of SSH, so the
playbooks are identical to what would run against a VM and only
[`inventory.ini`](./inventory.ini) changes.

```bash
./run-lab.sh
```

Evidence: [`01-idempotency.txt`](./evidence/01-idempotency.txt).

---

## The result

| Playbook | Run 1 | Run 2 |
|----------|-------|-------|
| [`playbook-naive.yml`](./playbook-naive.yml) | `changed=4` | `changed=4  ignored=1` |
| [`playbook.yml`](./playbook.yml) | `changed=5` | **`changed=0`** |

`changed=0` on the second run is the entire test. Anything else means a task is
reporting work it did not need to do.

---

## What broke — the naive playbook, on its second run

Every task in `playbook-naive.yml` produces the correct result on a clean host.
The first run is the one that gets tested; the damage shows up later.

**1. The motd grew.** `shell: echo "deployed by ansible" >> /etc/motd` appends
unconditionally:

```
$ docker exec web01 cat /etc/motd
...
deployed by ansible
deployed by ansible
```

Two runs, two lines. Ten runs, ten lines. Nothing ever reports a problem — the
task says `changed` and exits 0, exactly as it did the first time.

**2. The user task failed.** `shell: useradd -m -s /bin/bash appuser` exits 9
with *"user 'appuser' already exists"*. It only did not abort the play because
`ignore_errors: true` was there — which is how this class of bug survives:
someone hits the failure once, adds `ignore_errors`, and the playbook is now
permanently unable to distinguish "already done" from "actually broken".

**3. Every task reported `changed` forever.** With `changed=4` on every run, the
number carries no information. You cannot answer "did my change do anything?",
and handlers become useless — a `notify: restart nginx` attached to a task that
always reports changed restarts nginx on every single run.

---

## The fix — describe state, not actions

| Naive | Idempotent | Why it matters |
|-------|-----------|----------------|
| `shell: apt-get install -y nginx` | `apt: name=nginx state=present` | Only acts when the package is missing |
| `shell: useradd ...` | `user: name=appuser state=present` | No-op when the user exists, instead of exit 9 |
| `shell: echo ... >> /etc/motd` | `lineinfile: line=... state=present` | "Present exactly once", not "append" |
| `shell: cat > /etc/app.conf` | `template: src=... dest=...` | Compares content, writes only on difference |
| — | `command: ... args: creates=/var/lib/app-seeded` | Escape hatch when no declarative module exists |

Result after two runs:

```
deployed by ansible          <- one line

# Managed by Ansible — manual edits will be overwritten.
# Rendered for web01 on Debian 12.15
listen_port=8080
log_level=info
workers=4
```

---

## What idempotency buys beyond "safe to re-run"

**`--check --diff` becomes possible.** Declarative modules can compare desired
state against reality without applying anything. After editing a file by hand on
the target:

```
$ ansible-playbook playbook.yml --check --diff
web01 : ok=7  changed=1
web02 : ok=6  changed=0
```

Only the tampered host shows a pending change, and the host was **not** modified
by the check. A `shell` task cannot do this at all — there is no dry run for an
arbitrary command, so a naive playbook has no way to answer "what would this
do?" other than doing it.

**Handlers become trustworthy.** A handler fires only when a task genuinely
reported `changed`. That is only useful if `changed` is honest.

**Drift correction is free.** Running the playbook against the manually edited
host reverted `log_level=debug` back to `info` — the same reconcile-to-desired-
state behaviour as `terraform apply` in [module 27](../27-terraform-import-drift/README.md).

---

## Issues encountered

**Ansible silently ignored `ansible.cfg` and ran with no inventory.** The first
run printed `skipping: no hosts matched` and a warning that was easy to scroll
past:

```
world-writable-dir
[WARNING]: No inventory was parsed, only implicit localhost is available
```

Ansible **refuses to load a config file from a world-writable directory** — a
config anyone can edit can point at arbitrary plugin paths, which is remote code
execution. It warns and then continues with defaults, so the playbook "succeeds"
while doing nothing at all.

This repo lives on `/mnt/d`, a Windows drive mounted through DrvFs, where every
file is `0777` and `chmod` cannot change it. The fix is to name the file
explicitly, which Ansible trusts because the user asked for it:

```bash
export ANSIBLE_CONFIG="${PWD}/ansible.cfg"
```

**cowsay.** With cowsay installed, Ansible pipes every section header through it
and the output becomes ASCII cows. `nocows = True`.

---

## What I re-learned

- **The second run is the test, and it is the one nobody does.** Every task in
  the naive playbook is correct on a clean host. CI that provisions a fresh
  machine, runs the playbook once, and reports green will never catch any of
  this — the failure mode is specific to running against a host that already
  exists, which is every host in production.

- **`ignore_errors: true` converts a bug into a permanent blind spot.** It was
  added to work around `useradd` failing on the second run. It also guarantees
  that a genuinely broken user creation will never be noticed again. The right
  fix was a module that understands state; `ignore_errors` is what you reach for
  when you have decided not to.

- **`changed` is a signal, and non-idempotent tasks jam it.** When every task
  reports changed on every run, the count stops meaning anything, and everything
  downstream — handlers, change auditing, "what did this deploy actually do" —
  degrades with it.

- **`creates:` is the honest escape hatch.** Some operations genuinely have no
  state to inspect. `command` with `creates:` gives them a completion marker,
  which is much better than `shell` with no guard and much more honest than
  pretending a declarative module exists.

- **A warning that precedes silence deserves attention.** `world-writable-dir`
  scrolled past in one line, and the consequence was a playbook that reported
  success having done nothing. The same failure shape as module 21's ignored
  `--set` and module 22's dead Alertmanager route: valid-looking output,
  no error, nothing happening.
