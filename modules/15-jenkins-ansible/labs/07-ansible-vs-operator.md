# Lab 15.07 — Push versus reconcile

**EXTEND · 40 min**

> Skip if behind schedule. It is an architecture-review question and the answer
> "Ansible is old, operators are modern" is wrong.

## Context

You have now used both models on the same platform. Ansible pushes a change when
you run it; a controller maintains a state indefinitely. Knowing which problem
each solves is the point.

## The problem

### Part 1 — the same task, both ways

Pick something you can do either way — keeping a config file present and correct
on every node.

**Ansible:** a playbook, run on a schedule.
**Operator:** a DaemonSet or controller that reconciles continuously.

Implement both. Then break the desired state by hand and observe.

1. How long until each notices?
2. How long until each corrects it?
3. What happens if the machine was unreachable when Ansible ran?
4. What happens if the controller is down when someone breaks it?

### Part 2 — the comparison

| | Ansible | Controller |
|---|---|---|
| Detects drift | | |
| Corrects drift | | |
| Needs an agent | | |
| Works on a switch or a firewall | | |
| Works before the OS exists | | |
| Audit trail | | |
| Failure mode when it cannot reach the target | | |

### Part 3 — the boundary

5. Which parts of your platform are Ansible's, and which belong to a controller?
   Where exactly is the line?
6. What is the bootstrap argument? What must exist before a controller can run?
7. Could Argo CD from module 10 manage the VM worker? Why not?

Question 6 is the strongest structural argument: something has to create the
machine that runs the controller, and that something cannot be the controller.

### Part 4 — the anti-pattern

8. Describe a playbook running every five minutes from cron to keep a state
   correct. What is it badly reimplementing?
9. When is that actually reasonable?

Question 9 has a real answer: when the target cannot run an agent — a network
appliance, an embedded system, a machine with no outbound connectivity.

### Part 5 — write it down

10. In `NOTAS.md`, one paragraph you could say out loud in an architecture
    review: when you reach for configuration management and when you reach for a
    controller, and the property that decides it.

## Expected outcome

Both models implemented on the same task and measured, the comparison table
filled from observation, and a defensible one-paragraph position.

## Staged hints

<details><summary>Hint 1 — question 7</summary>

Argo CD reconciles Kubernetes objects through the API server. A VM is not a
Kubernetes object, so there is nothing to reconcile. You could wrap it in a CRD
and write a controller that configures the VM — which is a real pattern and also
a lot of work to reimplement what Ansible already does well.
</details>
