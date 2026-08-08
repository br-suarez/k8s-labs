# Lab 15.04 — Roles, vault and dynamic inventory

**CORE · 50 min**

## Context

Everything that turns a playbook that works into one a team can operate.

## The problem

### Part 1 — restructure into a role

```
roles/pulse_worker/
├── defaults/main.yml
├── tasks/main.yml
├── handlers/main.yml
├── templates/
├── files/
├── vars/main.yml
└── meta/main.yml
```

1. What goes in `defaults` versus `vars`? Which wins, and why does the
   distinction exist?
2. What is `meta/main.yml` for?
3. How do you test a role in isolation?

Question 1 catches people: `vars` has higher precedence than `defaults`, so
anything in `vars` cannot be overridden by the playbook — which is either what
you want or a bug.

### Part 2 — variable precedence

Set the same variable in five places: `defaults`, inventory group vars, inventory
host vars, `vars`, and `-e` on the command line.

4. Which wins? Predict first, then test.
5. Where does `set_fact` sit in that order?
6. Why is `-e` almost always the highest, and when is that a problem?

### Part 3 — secrets

```bash
ansible-vault create group_vars/prod/vault.yml
ansible-vault encrypt_string 'the-secret' --name 'db_password'
```

7. What is safe to commit? What is not?
8. Where does the vault password itself live in CI? What have you moved rather
   than solved?
9. Compare against the alternatives from module 12 — sealed secrets, an external
   secrets operator. When is vault the right choice?

Question 8 is the honest one: vault moves the problem to "protect one password
that unlocks everything", which is better but not solved.

### Part 4 — dynamic inventory

Stop maintaining a static host list. Write or configure a dynamic inventory —
against your cloud provider, or a script that lists Docker containers for this
lab.

```bash
ansible-inventory -i inventory/ --graph
ansible-inventory -i inventory/ --list | jq '.[] | keys'
```

10. What groups did it produce? Where did they come from?
11. What happens when a host disappears mid-run?
12. Why is dynamic inventory close to mandatory once instances are ephemeral?

## Expected outcome

A role with correct defaults/vars separation, the precedence order tested rather
than assumed, secrets encrypted with an honest assessment of what that solved,
and dynamic inventory working.

## Staged hints

<details><summary>Hint 1 — question 3</summary>

Molecule is the usual answer: it spins up a container, applies the role, runs
verification, and — critically — applies it **twice** to assert idempotence
automatically. That last check is the one you did by hand in lab 03, and
automating it is how it stays true.
</details>
