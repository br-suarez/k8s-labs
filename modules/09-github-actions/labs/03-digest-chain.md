# Lab 09.03 — The chain of custody

**CORE · 40 min**

## Context

This lab constructs the break-fix forwards. Do the break-fix first — diagnosing
a green pipeline that shipped the wrong artifact is worth more than being told
about it.

## The problem

### Part 1 — reproduce the race deliberately

Make two runs collide, on purpose:

```bash
# Two commits, seconds apart, both to main
git commit --allow-empty -m "run A" && git push
git commit --allow-empty -m "run B" && git push

gh run list --limit 2
```

With `concurrency` removed and `:latest` as the only tag, watch what each job
pulls. Capture the digests:

```bash
gh run view <run-id> --log | grep -i digest
crane digest ghcr.io/<you>/pulse-api:latest   # or docker buildx imagetools inspect
```

1. Did both runs test the same image?
2. Which run's artifact was orphaned?
3. Was there any point where a job could have detected the problem?

Question 3's answer is no, and that is the lesson: **the pipeline never knew what
it was handling.**

### Part 2 — build the chain

Make the digest a job output and consume it downstream:

```yaml
jobs:
  build:
    outputs:
      digest: ${{ steps.push.outputs.digest }}
      image:  ghcr.io/${{ github.repository_owner }}/pulse-api
    steps:
      - id: push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/pulse-api:${{ github.sha }}
            ghcr.io/${{ github.repository_owner }}/pulse-api:latest

  test:
    needs: build
    steps:
      - run: ./scripts/smoke-test.sh "${{ needs.build.outputs.image }}@${{ needs.build.outputs.digest }}"
```

Then add `concurrency` back.

### Part 3 — prove it is fixed

Repeat part 1. Both runs should now be serialised, and each should test exactly
its own artifact.

4. With `concurrency` on, what happened to the second run while the first was
   going?
5. If you had used `cancel-in-progress: true` on `main`, what would have been
   lost?

### Part 4 — the deploy side

6. Why does `kubectl set image` with `:latest` produce no rollout?
7. Why is `kubectl rollout restart` a bad workaround, specifically?
8. Write the command that detects a split fleet — different digests running under
   one Deployment.

## Expected outcome

A reproduced race with captured digests, a working digest chain, and the split-
fleet detection command in `NOTAS.md`.

## Verification

```bash
# The image in the spec must be a digest reference, never a tag
kubectl get deployment pulse-api -n pulse \
  -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q '@sha256:' \
  && echo "pinned by digest"
```

## Staged hints

<details><summary>Hint 1 — question 5</summary>

The first run would be cancelled mid-flight, leaving its commit with no built,
tested or deployed artifact. On `main` every commit deserves one. On a PR branch
the opposite is true: an older commit's run is worthless once a newer commit
exists.
</details>

<details><summary>Hint 2 — question 8</summary>

```bash
kubectl get pods -n pulse -l app=pulse-api \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].imageID}{"\n"}{end}' | sort -u | wc -l
```

Anything other than 1 is a split fleet. `imageID` is what is actually running;
`image` is only what was requested.
</details>
