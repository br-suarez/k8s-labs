# Lab 15.03 — Ansible from zero, and idempotency measured

**CORE · 50 min**

> Skim if your diagnostic confirmed `archive/sre-track/28-ansible-idempotency/`,
> and spend the time on labs 04 and 06.

## Context

Ansible is not legacy. It is the right answer for everything that is not a
container, including the machines your cluster runs on. This half of the module
gets two of its three blocks for that reason.

## The problem

### Part 1 — a target to configure

```bash
docker run -d --name pulse-vm --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host \
  ubuntu-systemd:24.04
```

Or a real VM if you prefer. You need systemd, because the point is configuring a
service, not running a container.

### Part 2 — the naive playbook

Write one that installs a binary, creates a user, writes a config and starts a
service — using `shell` and `command` for everything.

Run it twice.

1. What does the second run report?
2. Is anything actually different on the target after the second run? Check.
3. Which tasks lied about having changed something?

### Part 3 — the declarative version

Rewrite using proper modules: `get_url` with a checksum, `user`, `template`,
`systemd`.

4. Second run — `changed=0`?
5. Which task was hardest to make idempotent, and why?
6. Where did you need `changed_when` or `creates`, and what is the risk of each?

### Part 4 — handlers, and the trap

Restart the service **only when the config changes**.

```yaml
- name: Write config
  template:
    src: pulse-worker.conf.j2
    dest: /etc/pulse/worker.conf
  notify: restart pulse-worker

handlers:
  - name: restart pulse-worker
    systemd:
      name: pulse-worker
      state: restarted
```

7. Change the template. Does the service restart? Confirm from its uptime.
8. Run again with no changes. Does it restart? It must not.
9. **Now make a task fail after the config is written but before the end of the
   play.** What happened to the handler?

Question 9 is the trap: handlers run at the end of the play, so a failure in
between leaves the new config written and the service running the old one — the
worst of both states. `force_handlers` or a controlled `meta: flush_handlers`
is the fix.

### Part 5 — check mode

```bash
ansible-playbook site.yml --check --diff
```

10. Does it run clean? Which tasks cannot support check mode, and what do you do
    about them?
11. Why does `--check` matter operationally?

## Expected outcome

Naive and declarative versions compared, `changed=0` achieved and verified
independently, handlers working including the failure case, and check mode clean.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

`changed` is Ansible's claim, not a measurement. Compare file checksums,
timestamps and service start times before and after. A `command` task with
`changed_when: false` reports `ok` while modifying the system every run — the
inverse of the usual complaint and much harder to notice.
</details>
