# Lab 12.06 — base64 is not encryption

**CORE · 40 min**

## Context

Everyone knows Kubernetes Secrets are base64. Fewer people have looked at exactly
who can read them and through how many paths.

## The problem

### Part 1 — read a Secret you should not be able to

```bash
kubectl create secret generic demo -n pulse --from-literal=password=hunter2

# The obvious way
kubectl get secret demo -n pulse -o jsonpath='{.data.password}' | base64 -d

# From etcd directly, on the node
docker exec pulse-control-plane sh -c \
  'ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
   --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
   get /registry/secrets/pulse/demo' | strings | grep hunter2
```

1. Was it encrypted in etcd?
2. Who has read access to etcd on a real cluster? Who has read access to a node's
   disk, or to a backup of it?

### Part 2 — the leak nobody expects

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: leaky
  namespace: pulse
stringData:
  password: hunter2
EOF

kubectl get secret leaky -n pulse -o yaml | grep -A3 last-applied
```

3. What did you just find?
4. Which command causes it, and which does not? Test `apply` versus `create`.
5. Who can read that annotation? Is it covered by the same RBAC as the Secret?

### Part 3 — encryption at rest

Enable encryption at rest with an `EncryptionConfiguration` and confirm:

```bash
# Existing Secrets are NOT retroactively encrypted
kubectl get secrets -A -o json | kubectl replace -f -
```

6. Why is that re-write necessary? What does it tell you about enabling
   encryption on a cluster that already holds secrets?
7. Where does the encryption key live? What has it actually protected against?

Question 7 is the honest one: with the key on the same node as etcd, you have
protected against a stolen etcd backup, not against someone on the node.

### Part 4 — the alternatives

Implement **one** and compare it against plain Secrets:

| Option | Where the secret lives | Who can decrypt | Fits GitOps |
|---|---|---|---|
| Secret in Git (plain) | | | ✗ never |
| Sealed Secrets | | | |
| External Secrets Operator + cloud KMS | | | |
| Direct injection from a secrets manager | | | |

8. Which fits Pulse now, and which would you want at ten services?
9. With Sealed Secrets, what is safe to commit and what is not?
10. What happens to your sealed secrets if you lose the controller's private key?

Question 10 is the disaster-recovery question people discover the hard way.

## Expected outcome

A Secret read from etcd, the `last-applied-configuration` leak reproduced,
encryption at rest enabled with the re-write, and one alternative implemented and
compared.

## Cleanup

```bash
kubectl delete secret demo leaky -n pulse --ignore-not-found
```

## Staged hints

<details><summary>Hint 1 — question 4</summary>

`kubectl apply` stores the whole submitted object in the
`kubectl.kubernetes.io/last-applied-configuration` annotation — including
`stringData` in clear. `create` does not. So a Secret applied declaratively can
carry its own plaintext in an annotation, and annotations are visible to anyone
who can read the object's metadata. Server-side apply avoids it.
</details>

<details><summary>Hint 2 — question 10</summary>

The sealed secrets in Git become undecryptable. They are encrypted to that
controller's key, so losing it means re-sealing every secret from the original
values — which you had better still have somewhere. Backing up that key is a
prerequisite, and it is the single most commonly skipped step.
</details>
