# Lab 16.06 — The architecture review

**CORE · 45 min.** The last lab of the track.

## Context

Everything in this repository exists to make this document true. The
`ARCHITECTURE.md` you write here is the single most useful artifact you have for
an interview or an internal review — more than any individual module, because it
is the only one that shows judgement across the whole system.

## The problem

Write `platform/ARCHITECTURE.md`, in English, for an engineer who has never seen
Pulse and has 20 minutes.

### Required structure

**1. What the system does.** Three sentences. What it is for, who uses it, what
would go wrong for them if it stopped.

**2. The architecture.** One diagram and a paragraph. Services, data stores,
traffic path, the boundary between what runs in the cluster and what does not.

**3. Reliability.** The SLIs, the SLOs, why those and not others, and how they
are alerted on. Include the "whose failure is it" reasoning from module 07 —
that distinction is what shows you thought about it rather than copied a
template.

**4. Delivery.** How a change reaches production: pipeline, artifact identity,
GitOps, canary, and what stops a bad release at each stage.

**5. Security posture.** Supply chain, admission control, runtime hardening,
secrets — and be honest about the gap between admission control and cluster
state.

**6. Operations.** How it is patched, backed up, restored, and what happens
during an incident. Include the emergency procedures for GitOps and for policy.

**7. The decisions, and their trade-offs.** The heart of the document. For each,
what you chose, what you rejected, and the condition that would change your mind:

| Decision | Chosen | Rejected | Would change if |
|---|---|---|---|
| Local cluster | kind | k3d, minikube | |
| Edge routing | Gateway API | Ingress, service mesh | |
| GitOps controller | Argo CD | Flux, CI apply | |
| Progressive delivery | Canary | Blue/green, rolling | |
| Cloud | GCP | AWS, Azure | |
| Config management | Ansible | Operator, cloud-init | |
| Observability | OTel + Prometheus | eBPF-only, vendor agent | |

**8. What is wrong with it.** The section that earns the most credit and that
almost nobody writes. Known weaknesses, unmitigated risks, things you would build
differently with more time, and the parts you are least confident about.

**9. What you would do next**, with the reasoning for the ordering.

## The test

Present it out loud, in 20 minutes, to yourself or to someone else. Then:

1. Where did you hesitate?
2. Which decision could you not defend without checking something?
3. Which section did you want to skip?

Those three are your remaining gaps, and they are more useful than the document
itself.

## The exit criteria, one last time

The whole track was built toward these four. Read them again and answer honestly
for the platform as a whole:

- [ ] I can design and implement this **without documentation open**.
- [ ] I can debug a failure I have not seen before in it, under pressure.
- [ ] I can explain the trade-offs of every decision against two alternatives.
- [ ] I can defend it in a senior SRE interview and in an architecture review.

The fourth one you have just done. The other three you have been measuring all
along in `TRACKER.md`.

## Expected outcome

`ARCHITECTURE.md` complete with all nine sections — especially section 8 —
presented out loud once, and the three hesitation questions answered.

---

## Y ya está

Diecinueve módulos, veintiocho semanas, una plataforma construida capa a capa y
rota a propósito unas cuantas veces.

Lo que queda no es un certificado: es un repositorio donde cada módulo enseña qué
se rompió, cómo lo diagnosticaste y qué decidiste — incluidas las veces que te
equivocaste primero. Eso es lo que se puede defender.
