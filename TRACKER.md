# TRACKER — Progreso

Se actualiza al cerrar cada módulo, no al final. Un tracker rellenado de memoria
tres semanas después no sirve para nada.

**Estados:** ⬜ pendiente · 🔵 en curso · ✅ cerrado · ⚠️ cerrado con deuda

---

## Progreso por módulo

| # | Módulo | Estado | Diagnóstico | Inicio | Cierre | Bloques (est/real) | Nivel |
|---|---|---|---|---|---|---|---|
| 00 | Bootstrap & Environment | ⬜ | — | | | 2 / | |
| 01 | Linux & Scripting | ⬜ | ⬜ | | | 4 / | |
| 02 | NGINX as Edge | ⬜ | ⬜ | | | 4 / | |
| 03 | Docker & Supply Chain | ⬜ | ⬜ | | | 4 / | |
| 04 | Kubernetes Core | ⬜ | ⬜ | | | 4 / | |
| 05 | Gateway API | ⬜ | ⬜ | | | 5 / | |
| 06 | Kubernetes Advanced | ⬜ | ⬜ | | | 5 / | |
| 07 | Prometheus & Grafana | ⬜ | ⬜ | | | 4 / | |
| 08 | OpenTelemetry | ⬜ | ⬜ | | | 6 / | |
| 08b | **eBPF & Profiling** | ⬜ | ⬜ | | | 4 / | |
| 08c | **Game Day I** | ⬜ | — | | | 2 / | |
| 09 | GitHub Actions | ⬜ | ⬜ | | | 4 / | |
| 10 | GitOps con Argo CD | ⬜ | ⬜ | | | 5 / | |
| 11 | Progressive Delivery | ⬜ | ⬜ | | | 4 / | |
| 12 | DevSecOps | ⬜ | ⬜ | | | 5 / | |
| 13 | Terraform | ⬜ | ⬜ | | | 5 / | |
| 14 | Google Cloud | ⬜ | ⬜ | | | 7 / | |
| 15 | Jenkins & Ansible | ⬜ | ⬜ | | | 3 / | |
| 16 | Game Day II & Hardening | ⬜ | ⬜ | | | 5 / | |

**Columna Diagnóstico:** ✅ aprobado (ruta rápida) · ❌ no aprobado (módulo completo)

**Columna Nivel:** autoevaluación 1–5 contra los cuatro criterios de salida.
Escribe el más bajo de los cuatro, no el promedio. Un 5 en implementación con un
2 en depuración es un 2 — en producción te va a tocar la parte de depurar.

| Nivel | Significa |
|---|---|
| 1 | Lo sigo con la guía delante |
| 2 | Lo hago solo, consultando documentación |
| 3 | Lo hago sin documentación; depurar me cuesta |
| 4 | Lo hago sin documentación y depuro fallos nuevos |
| 5 | Lo anterior + defiendo trade-offs frente a 2 alternativas |

**El objetivo del plan es 4 en todos los módulos, y 5 en al menos seis.** Un 3
no es fracaso: es un módulo que necesita una sesión de repaso extra.

---

## Deuda declarada

Todo lo que quedó a medias. Si está aquí, existe; si no, se olvida.

| Módulo | Qué quedó pendiente | Por qué | Cuándo lo retomo |
|---|---|---|---|
| | | | |

---

## Break-fix: marcador

El indicador más honesto del progreso real. Un tiempo de diagnóstico que baja a
lo largo de los módulos es la única prueba de que estás mejorando como SRE, y no
solo acumulando herramientas.

| Módulo | Tiempo a diagnóstico | Tiempo a solución | Pistas usadas (0–3) | ¿Lo habría resuelto en guardia? |
|---|---|---|---|---|
| 00 | — | — | — | — |
| 01 | | | | |
| 02 | | | | |
| 03 | | | | |
| 04 | | | | |
| 05 | | | | |
| 06 | | | | |
| 07 | | | | |
| 08 | | | | |
| 08b | | | | |
| **08c** | **mediana:** | | sin pistas | |
| 09 | | | | |
| 10 | | | | |
| 11 | | | | |
| 12 | | | | |
| 13 | | | | |
| 14 | | | | |
| 15 | | | | |
| 16 | | | | |

---

## Sesiones de repaso

| Fecha prevista | Semana | Tipo | Módulos | Hecho | Qué se me había olvidado |
|---|---|---|---|---|---|
| 2026-09-14 | 7 | 30 d | 00–02 | ⬜ | |
| 2026-10-26 | 13 | 30 d | 05–07 | ⬜ | |
| 2026-10-26 | 13 | 90 d | 00–02 | ⬜ | |
| 2026-12-21 | 21 | 30 d | 08b–12 | ⬜ | |
| 2026-12-21 | 21 | 90 d | 05–08 | ⬜ | |
| 2027-02-08 | 28 | 90 d | 09–14 | ⬜ | |

La última columna es la más valiosa del archivo. Lo que se te olvidó a los 30
días es lo que se te va a olvidar en una entrevista.

---

## Estado del capstone

La plataforma debe quedar desplegable al cerrar cada módulo. Si no lo está, el
módulo no está cerrado.

| Módulo | Capa añadida | ¿Despliega? | Comando de verificación |
|---|---|---|---|
| 01 | Harness `verify.sh` | ⬜ | `make verify` |
| 02 | Edge NGINX + TLS | ⬜ | `./platform/scripts/verify.sh nginx` |
| 03 | Compose, distroless | ⬜ | `docker compose up -d && make verify` |
| 04 | Kubernetes (kind) | ⬜ | `kubectl get pods -n pulse` |
| 05 | Gateway API | ⬜ | `kubectl get httproute -n pulse` |
| 06 | Estado + backup | ⬜ | `./platform/scripts/restore-drill.sh` |
| 07 | Métricas + SLO | ⬜ | `./platform/scripts/verify.sh slo` |
| 08 | Trazas + exemplars | ⬜ | `./platform/scripts/verify.sh traces` |
| 08b | Profiling continuo, sin tocar el código | ⬜ | `./platform/scripts/verify.sh profiling` |
| 08c | Postmortem I + remediación | ⬜ | `POSTMORTEM-1.md` y una comprobación nueva en el harness |
| 09 | Pipeline CI | ⬜ | badge verde en GitHub |
| 10 | GitOps | ⬜ | `argocd app get pulse` |
| 11 | Canary | ⬜ | `kubectl argo rollouts status pulse-api` |
| 12 | Cadena de suministro | ⬜ | `cosign verify ...` |
| 13 | Terraform | ⬜ | `terraform plan -detailed-exitcode` |
| 14 | GKE | ⬜ | `terraform destroy` limpio |
| 15 | Worker legacy | ⬜ | `ansible-playbook --check` con `changed=0` |
| 16 | Game Day | ⬜ | postmortem publicado |

---

## Bitácora de decisiones

Cada vez que elijas entre alternativas, anótalo aquí. En una entrevista de
arquitectura no te preguntan qué hiciste, te preguntan por qué. Este es el
archivo del que sale esa respuesta.

| Fecha | Decisión | Alternativas descartadas | Por qué | ¿Lo repetiría? |
|---|---|---|---|---|
| 2026-08-02 | kind como cluster local | k3d, minikube | k3s oculta componentes (etcd→SQLite, Traefik) cuyos fallos hay que saber depurar | |
| 2026-08-02 | Argo CD como único GitOps | Flux | Un controlador a fondo > dos por encima; Flux queda como trade-off teórico | |
| 2026-08-02 | GCP como nube principal | AWS, Azure | Una nube a fondo; las otras como mapeo conceptual | |
| | | | | |
