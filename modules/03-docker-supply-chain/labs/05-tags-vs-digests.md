# Lab 03.05 — Tags are not identity

**CORE · 30 min**

## Context

Every deployment you write from module 09 onwards references images by digest.
This lab is why.

## The problem

### Part 1 — move a tag under yourself

Run a local registry, publish an image, then republish something different under
the same tag:

```bash
docker run -d -p 5000:5000 --name registry registry:2

# Version A
docker tag pulse-api:lab localhost:5000/pulse-api:v1
docker push localhost:5000/pulse-api:v1
docker inspect localhost:5000/pulse-api:v1 --format '{{index .RepoDigests 0}}'

# Change something, rebuild, push under the SAME tag
sed -i 's/pulse-api listening/pulse-api v2 listening/' platform/services/pulse-api/main.go
docker build -t localhost:5000/pulse-api:v1 platform/services/pulse-api
docker push localhost:5000/pulse-api:v1
docker inspect localhost:5000/pulse-api:v1 --format '{{index .RepoDigests 0}}'
```

Two different digests, same tag. Nothing warned you.

### Part 2 — the consequence

A node that pulled before the change is running version A. A node that pulls
after is running version B. Both report `image: pulse-api:v1`.

Reproduce it:

```bash
docker rmi localhost:5000/pulse-api:v1
docker pull localhost:5000/pulse-api:v1     # gets B
```

Then answer in `NOTAS.md`:

1. How would you discover this had happened, from inside a running cluster?
2. `imagePullPolicy: IfNotPresent` versus `Always` — how does each interact with
   this failure?
3. Why does `:latest` make this strictly worse?

### Part 3 — pin by digest

```bash
DIGEST=$(docker inspect localhost:5000/pulse-api:v1 --format '{{index .RepoDigests 0}}')
docker pull "$DIGEST"
```

Update your Compose file to reference images by digest. Then answer:

4. What did you just make harder operationally?
5. How do you get the benefit of digest pinning without updating them by hand
   forever?

## Expected outcome

Two digests captured for the same tag, and the five questions answered.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

`kubectl get pods -o jsonpath='{.items[*].status.containerStatuses[*].imageID}'`
reports the **digest actually running**, not the tag requested. Comparing that
across pods of the same Deployment is how you find a split fleet — and it is a
genuinely useful diagnostic to remember.
</details>

<details><summary>Hint 2 — question 5</summary>

Automated digest bumping: Renovate, Dependabot, or the Argo CD image updater
from module 10. The pattern is that a machine proposes the change as a commit,
so the pin stays current and every change is still reviewed and auditable.
</details>

## Cleanup

```bash
docker rm -f registry
git checkout platform/services/pulse-api/main.go
```
