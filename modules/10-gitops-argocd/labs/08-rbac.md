# Lab 10.08 — AppProjects and multi-tenancy

**EXTEND · 35 min**

> Skip if behind schedule. Worth doing before proposing Argo CD for a shared
> cluster, because the default install trusts everyone equally.

## Context

You saw in lab 01 that the application-controller runs with very broad
permissions. AppProjects are how you stop every Application inheriting all of it.

## The problem

### Part 1 — the default is permissive

```bash
kubectl get appproject default -n argocd -o yaml
```

1. What source repositories may an Application in `default` use?
2. What destinations may it deploy to?
3. What resource kinds may it create?
4. Given those three answers, what can someone with permission to create an
   Application do to your cluster?

### Part 2 — constrain it

Create a `pulse` AppProject that permits only:

- The Pulse repository, and only specific paths
- The `pulse` and `pulse-*` namespaces on the local cluster
- The resource kinds Pulse actually uses — no ClusterRole, no CRD, no namespace
  creation

Move the Pulse Applications into it and confirm they still work.

### Part 3 — prove the constraints bite

Try each and record the error:

5. An Application in project `pulse` pointing at a different repository.
6. One deploying to `kube-system`.
7. One creating a `ClusterRoleBinding`.

All three must be refused. If any succeeds, your project is not constraining what
you think it is.

### Part 4 — RBAC for humans

Configure `argocd-rbac-cm` so that a `developer` role can sync and view Pulse but
cannot delete Applications or change project settings.

8. Test it with a second account. What exactly can they do?
9. Can they still cause damage? How?

Question 9's honest answer is yes — sync permission plus write access to the Git
repo is equivalent to deploy permission. **The real boundary is Git.**

### Part 5 — the model

10. Write the mapping in `NOTAS.md`: for a shared cluster with three teams, what
    do you use AppProjects for, what do you use Kubernetes RBAC for, and what do
    you use Git branch protection for? Each solves something the others cannot.

## Expected outcome

A constraining AppProject with three refusals demonstrated, a restricted human
role, and the three-layer model written out.

## Staged hints

<details><summary>Hint 1 — question 4</summary>

With the `default` project, an Application may point at any repository, deploy to
any namespace on any registered cluster, and create any resource kind — including
ClusterRoleBindings. So permission to create an Application is, in practice,
cluster-admin with extra steps. That is why the first thing to do after
installing Argo CD is to stop using `default`.
</details>
