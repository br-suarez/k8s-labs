# Toil Analysis — On-call triage for availability pages

## Is this actually toil?

"Toil" is not a synonym for "work I dislike". Google's SRE book defines it by six
properties, and the honest first step is checking whether the task qualifies —
automating something that is *not* toil is how engineers spend a quarter building
a tool nobody needed.

The task: **when `SLODemoAvailabilityFastBurn` fires, run the module 20 runbook**
— confirm the alert is real, scope the failure, check the error budget, check
what shipped recently, check pod restarts and logs.

| Property | Does it apply? |
|----------|----------------|
| **Manual** | Yes. 11 commands typed by hand, output read by eye. |
| **Repetitive** | Yes. Identical every time; only the service name changes. |
| **Automatable** | Yes. Every step is a Prometheus query or a `kubectl get` — no judgement is required to *gather* the data. Judgement starts after. |
| **Tactical / interrupt-driven** | Yes, by definition. It exists because a page arrived. |
| **No enduring value** | Yes. The service is in exactly the same state after triage as before. Nothing is improved by having run it. |
| **Scales linearly with the service** | Yes. Twice the services, or twice the alerts, means twice the triage. |

Six out of six. This is toil.

## What is deliberately NOT automated

The tool **gathers and formats**. It does not decide, and it does not act.

- It does not restart pods.
- It does not roll back a deployment.
- It does not silence the alert.
- Its RBAC has `get`/`list` only — no `create`, `delete`, or `patch`
  ([`deploy/rbac.yaml`](./deploy/rbac.yaml)).

Auto-remediation is a separate decision with a much worse failure mode: a
diagnostic that gets it wrong wastes a minute, an auto-remediation that gets it
wrong turns a degradation into an outage. Gathering evidence is unambiguously
safe; acting on it is not. The report ends with the data and the branch points
("all pods similar = systemic, one outlier = that pod"), leaving the call to a
human.

## The measurement

Measured directly on the cluster ([`evidence/01-toil-measurement.txt`](./evidence/01-toil-measurement.txt)):

| | Manual runbook | Automated triage |
|---|---|---|
| Commands a human types | **11** | **0** |
| Mechanical execution time (avg of 3) | 1.34s | 0.68s |
| Output format | 6 raw JSON blobs + 5 kubectl tables | one formatted report |
| Runs when nobody is awake | no | yes |

**The 2x mechanical speedup is not the point, and quoting it as the benefit
would be dishonest.** A shell script executing 11 commands back to back is
already near-optimal; there was never 10 minutes of *CPU* time to reclaim.

The time being spent is human time, and it is spent on things the stopwatch
above cannot see:

1. Waking up and acknowledging the page.
2. Finding the runbook.
3. Pasting 11 commands, one at a time, into a terminal.
4. Reading `{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1785640859.189,"13.544611949047162"]}]}}`
   and mentally converting `0.13544...` into "13.5%".
5. Holding six numbers in working memory to answer "is this one pod or all of them".

### Estimated human time — labelled as an estimate

The lab cannot measure a sleep-deprived human, so this is an assumption, stated
so it can be argued with rather than hidden:

- **Assumption:** an engineer takes 6–10 minutes to work through 11 commands and
  interpret raw JSON at 3am, and this service pages ~4 times a month.
- On those numbers: **~30 min/month, ~6 hours/year, per service**, and it scales
  linearly with services and alert volume.

What the lab *does* measure without assumptions is the interval that matters
most: **time from the alert firing to a complete diagnosis existing**, with no
human involved at all. See [`evidence/02-e2e-timeline.txt`](./evidence/02-e2e-timeline.txt).

## The honest cost side

The automation is not free:

- ~150 lines of bash, ~90 lines of Python, a Dockerfile, RBAC, a Deployment and
  an AlertmanagerConfig — all of which is now code that can break.
- It has its own failure mode: if the receiver is down, the page still arrives
  and the human falls back to the manual runbook. That is why the manual runbook
  is kept in the repo rather than deleted — the fallback has to still exist.
- The queries duplicate knowledge held in the SLO rules. If the SLI definition
  changes, this must change with it.

Toil automation that costs more to maintain than the toil it removes is a net
loss. The reason this one is worth it: the queries are stable (they are the
SLIs, which change rarely), and the value scales with every new service that
adopts the same alert.
