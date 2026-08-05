# Lab 09.04 — Scan, SBOM, and the exception path

**CORE · 45 min**

## Context

The scanning half of the pipeline. Module 12 turns these artifacts into
enforcement; here you produce them and — more importantly — decide what to do
when the scan says no on a Friday afternoon.

## The problem

### Part 1 — scan

Add Trivy (`v0.72.0`) against the image you built, by digest.

1. How many findings on your distroless image? How many on the `golang` build
   stage image? Explain the difference in one sentence.
2. Which findings are in **your** code versus in the base image versus in a
   transitive dependency?
3. What is the difference between a vulnerability that is present and one that is
   **reachable**?

### Part 2 — SBOM

Generate an SBOM and upload it as a build artifact.

4. SPDX vs CycloneDX — what would make you pick one?
5. Open it. How many components? Does the count surprise you for a binary you
   thought had no dependencies?
6. Answer a real question with it: *"Are we affected by a CVE in library X?"*
   Time yourself. How long would that take without the SBOM?

### Part 3 — fail the build, then unblock it

Make the pipeline fail on HIGH and CRITICAL. Then confront the situation that
actually happens:

> It is Friday 17:00. A CRITICAL appears in a transitive dependency. No fix is
> published. The release fixes a customer-facing bug.

Design the exception path. It must have all four:

- A way to proceed **that is recorded**, not a flag someone flips quietly
- An expiry — exceptions that never expire are not exceptions
- A named owner
- Visibility: something must show which exceptions are live right now

Implement it. `.trivyignore` with mandatory expiry dates and a comment format you
can lint is a reasonable starting point.

7. Why is "just lower the threshold to CRITICAL-only" the wrong fix?
8. What stops an exception from becoming permanent?

### Part 4 — scanning is not enough

9. Your CI scans the image you build. Name three cases it does not cover.
10. What does that imply about where enforcement has to live?

Question 10 is the bridge to module 12.

## Expected outcome

Scan and SBOM in the pipeline, a real CVE question answered from the SBOM and
timed, and a working exception path with expiry and visibility.

## Staged hints

<details><summary>Hint 1 — question 3</summary>

Present means the vulnerable code is in the image. Reachable means your
application actually calls the vulnerable path. Most findings are present and not
reachable, which is why raw scanner output has a terrible signal-to-noise ratio
and why teams learn to ignore it. Reachability analysis is what makes scanning
actionable, and it is why Go's `govulncheck` is more useful than a generic
scanner for Go code — it checks call graphs, not package lists.
</details>

<details><summary>Hint 2 — question 9</summary>

(a) Images deployed before the CVE was published — CI ran when it was clean.
(b) Images that reached the cluster without passing CI at all. (c) The base image
you scanned once and pinned; new CVEs against it appear later. All three mean
scanning must be continuous against the registry *and* enforced at admission.
</details>
