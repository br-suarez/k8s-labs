# Lab 13.02 — A module with a real interface

**CORE · 50 min**

## Context

A module that just wraps a resource adds indirection without abstraction. A good
module encapsulates a **decision**.

## The problem

### Part 1 — write one worth having

Build `modules/pulse-service` that encapsulates how your organisation deploys a
service: naming convention, required labels, sane defaults, and the resources
that always go together.

Requirements:

1. Variables with **validation** — reject bad input at plan time, not at apply.
2. Sensible defaults so the common case needs three arguments, not fifteen.
3. Outputs that consumers actually need.
4. A `versions.tf` pinning provider versions exactly.
5. A README documenting every variable and one worked example.

```hcl
variable "service_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.service_name))
    error_message = "service_name must be lowercase alphanumeric with hyphens, 3-30 chars."
  }
}
```

6. Write a validation that catches a mistake you have actually made before.

### Part 2 — consume it twice

Two environments differing in at least three parameters, both using the module.

7. How much duplicated HCL between the two? Should be near zero.
8. What did you have to expose as a variable that you did not expect?

Question 8 is the design feedback: every variable you were forced to add is a
decision the module failed to encapsulate.

### Part 3 — versioning

Pin the module by version. Then:

9. Make a backwards-incompatible change. How does a consumer find out?
10. What is the difference between `= 1.2.0`, `~> 1.2`, and `>= 1.2` for a
    module you do not control?
11. Which do you use, and what is the cost?

### Part 4 — know when to stop

12. Count variables versus resources in your module. What ratio starts to worry
    you?
13. Refactor deliberately in the wrong direction — make it configurable enough
    to be useless — then describe the smell in one sentence.

## Expected outcome

A module with validation, two consumers with almost no duplication, a
version-pinning decision, and a written description of the over-configuration
smell.

## Staged hints

<details><summary>Hint 1 — question 10</summary>

`= 1.2.0` exact: reproducible, ages. `~> 1.2` allows 1.x: gets patches
automatically and also gets whatever else shipped in a minor release, which for a
module can include a `ForceNew` attribute change. `>= 1.2` allows anything
including majors — almost never right. For modules you do not control, exact and
renew via PR, same as image digests and action SHAs.
</details>

<details><summary>Hint 2 — question 12</summary>

More variables than resources means consumers are configuring everything, so the
module is not deciding anything — it is a syntax layer over the provider with
extra steps. At that point calling the resource directly is clearer.
</details>
