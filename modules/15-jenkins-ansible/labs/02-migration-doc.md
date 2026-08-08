# Lab 15.02 — The migration document

**CORE · 50 min**

## Context

The deliverable of the Jenkins half. Not because writing documents is the job,
but because "should we migrate off Jenkins?" is a question you will be asked, and
the answer that gets respect includes the case for staying.

## The problem

Write `modules/15-jenkins-ansible/MIGRATION.md`, in English, for a team that has
Jenkins and is considering GitHub Actions.

### Required sections

**1. Syntax mapping.** The easy part, so do it quickly.

| Jenkins | GitHub Actions | Notes |
|---|---|---|
| `pipeline { }` | `jobs:` | |
| `stage` | `job` or `step` | |
| `agent` | `runs-on` | |
| `environment` | `env` | |
| `credentials()` | `secrets` | |
| `post { always }` | `if: always()` | |
| `when` | `if` | |
| Shared library | Reusable workflow / composite action | |

**2. The plugin inventory.** This is where the real work is.

```
Jenkins → Manage Jenkins → Plugins → Installed
```

For each plugin actually used by the pipeline: what does it do, and is there an
equivalent? Three buckets — direct equivalent, needs rebuilding, no equivalent.

1. How many plugins are installed? How many are actually used?
2. Which ones have no equivalent? Those are the migration blockers.

**3. Real numbers.** Both systems built the same artifact — compare:

| | Jenkins | GitHub Actions |
|---|---|---|
| Build time, cold | | |
| Build time, warm cache | | |
| Time to onboard a new service | | |
| Infrastructure you operate | | |
| Cost model | | |
| What happens when it breaks at 3am | | |

**4. What gets harder.** Be specific:
- Self-hosted runners if you need special hardware
- No equivalent for some plugins
- Costs scale with usage rather than being fixed
- Vendor coupling to GitHub

**5. Migration strategy.** Concrete and reversible: run both in parallel, migrate
one service, compare, expand. Include the stopping rule.

**6. The recommendation — including when not to migrate.**

## The section that matters

Section 6 must contain a defensible case for **staying on Jenkins**. For example:
a team with deep Jenkins expertise, pipelines depending on plugins with no
equivalent, no security pressure, and a migration cost measured in months against
a benefit measured in preference.

3. Write that case as convincingly as you can, then write your actual
   recommendation.

A document that only argues one direction is advocacy. The one that names the
conditions under which its own recommendation is wrong is engineering — same
standard as the Gateway API migration document in module 05.

## Expected outcome

`MIGRATION.md` complete, with the plugin inventory built from your own
installation and the comparison table filled with measured numbers.

## Staged hints

<details><summary>Hint 1 — the plugin inventory</summary>

A default Jenkins install has 80+ plugins and a typical pipeline uses a handful.
The number that matters is the second one. Migrations get estimated on the first
and then take three times as long because someone counted wrong.
</details>
