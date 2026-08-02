# PLAN — Calendario semana por semana

**Inicio:** lunes 2026-08-03
**Objetivo:** 2027-02-14
**Ritmo:** 3 bloques de 120 min por semana (lunes, martes, miércoles) = 6 h/semana

---

## Las dos rutas

Este plan tiene dos calendarios porque tiene dos públicos, y el diagnóstico de
cada módulo decide en cuál estás.

| Ruta | Bloques | Semanas | Fin |
|---|---|---|---|
| **A — con diagnósticos aprobados** (la esperada para ti) | 72 | 24 contenido + 4 reserva = 28 | **2027-02-14** |
| **B — módulo completo, sin saltar nada** (principiante) | 96 | 28 contenido + 4 reserva = 32 | 2027-03-14 |

La ruta A asume que apruebas el diagnóstico de los módulos 01, 03, 04, 11 y 13 —
razonable dado el trabajo de `archive/sre-track/`. **Si no lo apruebas, no pasa
nada: haces el módulo completo y te desplazas hacia la ruta B.** El calendario de
abajo es el de la ruta A; las 4 semanas de reserva son exactamente el colchón que
compran los diagnósticos.

### Reajuste de pesos (2026-08-02)

**Ronda 1 — cero bloques netos:**

| Cambio | Bloques | Motivo |
|---|---|---|
| Gateway API 6 → 5 | −1 | Ingress domina la base instalada; es inversión a 2–3 años, no a corto plazo. Los labs 06–08 pasan a opcionales |
| Jenkins & Ansible 4 → 3 | −1 | Leer un Jenkinsfile sabiendo Actions es traducción, no aprendizaje. Dentro del módulo, 1 bloque a Jenkins y 2 a Ansible, que no es legacy |
| **Game Day I** tras el módulo 08 | +2 | El módulo de mayor valor estaba solo al final, donde el protocolo de atraso lo sacrifica |

**Ronda 2 — +6 bloques, de 26 a 28 semanas:**

| Cambio | Bloques | Motivo |
|---|---|---|
| **Módulo 08b — eBPF y profiling continuo** | +4 | Responde la pregunta que la instrumentación no puede: qué haces cuando no puedes tocar el código. Va justo después del 08 para que el contraste sea agudo |
| Módulo 14 — unit economics y rightsizing | +1 | El coste es una restricción sobre decisiones de fiabilidad. Coste por 1.000 sondeos, derivado de datos que ya generaste. $0 |
| Módulo 16 — un experimento diseñado | +1 | Los Game Days son simulacros: entrenan reacción. Un experimento con hipótesis y estado estable declarado antes es otra disciplina, y es la que escala |

Descartado en esta ronda: **plataformas internas / IDP**. Montar un Backstage en
dos semanas produce algo superficial, y superficial es peor que ausente — invita
a decir en una entrevista que sabes algo que no sabes.

---

## Checkpoints — la red de seguridad del capstone

El capstone acumula, y eso es lo que lo hace valioso. También lo convierte en un
punto único de fallo: una plataforma a medio migrar en el módulo 09 puede
bloquear el 10 por razones que no tienen nada que ver con aprender el 10.

**La regla: al cerrar cada módulo, etiquetas el estado bueno conocido.**

```bash
./scripts/checkpoint.sh save 05
```

Si un módulo posterior se atasca por deuda de plataforma y no por el material:

```bash
./scripts/checkpoint.sh list
./scripts/checkpoint.sh diff 05        # qué cambió desde entonces
./scripts/checkpoint.sh restore 05     # rama nueva desde ese estado
./scripts/checkpoint.sh rebuild 05     # cluster desde cero hasta ahí
```

`restore` crea una **rama**, nunca descarta tu trabajo posterior: recuperarte de
un estado malo no puede costarte lo que te llevó hasta él.

Esto **no** permite saltarse un módulo — la etiqueta solo existe si lo cerraste
bien. Lo único que hace es impedir que un problema de entorno se convierta en un
problema de currículo.

No optimices para llegar el 14 de febrero. Optimiza para que los criterios de
salida se cumplan de verdad. La fecha es maleable; el criterio no.

---

## Calendario

Leyenda de bloques: `05×3` = tres bloques del módulo 05 esa semana.

| Sem | Lunes | Bloques | Hito |
|---|---|---|---|
| 1 | 2026-08-03 | `00×2` `01×1` | Entorno reproducible, `verify-setup.sh` pasa |
| 2 | 2026-08-10 | `01×1` `02×2` | Harness `verify.sh` terminado |
| 3 | 2026-08-17 | `02×2` `03×1` | **Pulse tras NGINX con TLS** |
| 4 | 2026-08-24 | `03×1` `04×2` | **Pulse en Compose, imágenes distroless** |
| 5 | 2026-08-31 | `05×3` | Pulse en kind |
| 6 | 2026-09-07 | `05×2` `06×1` | **NGINX sustituido por Gateway API** |
| 7 | 2026-09-14 | — | 🟡 **RESERVA** + repaso 30 d (mód. 00–02) |
| 8 | 2026-09-21 | `06×3` | |
| 9 | 2026-09-28 | `06×1` `07×2` | **Postgres con estado, drill de backup** |
| 10 | 2026-10-05 | `07×2` `08×1` | **SLO definido, recording rule 8s → <1s** |
| 11 | 2026-10-12 | `08×3` | |
| 12 | 2026-10-19 | `08×2` `08b×1` | **Trazas propias, exemplars métrica→traza** |
| 13 | 2026-10-26 | — | 🟡 **RESERVA** + repaso 30 d (mód. 05–07) |
| 14 | 2026-11-02 | `08b×3` | **Flamegraph de un pod vivo, sin tocarlo** |
| 15 | 2026-11-09 | `08c×2` `09×1` | 🔥 **Game Day I + postmortem** |
| 16 | 2026-11-16 | `09×3` | **Pipeline verde con SBOM** |
| 17 | 2026-11-23 | `10×3` | |
| 18 | 2026-11-30 | `10×2` `11×1` | **GitOps: Argo CD gobierna el cluster** |
| 19 | 2026-12-07 | `11×1` `12×2` | **Canary con rollback automático por SLO** |
| 20 | 2026-12-14 | `12×3` | **Solo imágenes firmadas admitidas** |
| 21 | 2026-12-21 | — | 🎄 **RESERVA** — Navidad |
| 22 | 2026-12-28 | — | 🎄 **RESERVA** — Navidad |
| 23 | 2027-01-04 | `13×3` | Infra como módulos Terraform |
| 24 | 2027-01-11 | `14×3` | |
| 25 | 2027-01-18 | `14×3` | **Pulse en GKE, y destruido** |
| 26 | 2027-01-25 | `14×1` `15×2` | Coste por 1.000 sondeos |
| 27 | 2027-02-01 | `15×1` `16×2` | Comparativa Jenkins vs Actions |
| 28 | 2027-02-08 | `16×3` | 🏁 **Game Day II + revisión de arquitectura** |

Las semanas 21 y 22 son reserva por calendario, no por diseño. Si llegas
adelantado, adelanta el módulo 14 — es el único con costo y conviene ejecutarlo
concentrado.

**Sobre la semana 15:** el Game Day I cabe entero en una sola semana, a
propósito. El bloque suelto del módulo 09 va detrás porque el 09 depende del 03,
no del 08, así que no hay razón para esperarlo. Un postmortem escrito dos semanas
después del incidente es ficción, y partir el ejercicio por una semana de reserva
garantizaría justo eso.

**Sobre el Game Day I:** es el cambio de diseño más importante del plan. El
módulo de mayor valor —depurar algo que no habías visto, bajo presión— estaba
solo al final, en la posición exacta que el protocolo de atraso sacrifica. Ahora
hay uno a mitad de camino, contra un sistema de siete capas en vez de trece, y
los dos postmortems separados por trece semanas son la medida más honesta de
progreso de todo el repo.

**Sobre el módulo 08b (eBPF):** se parte entre las semanas 12 y 14 por la reserva
del medio, y no pasa nada — no es un ejercicio de sesión única. El Game Day sí lo
es, y por eso se protegió.

---

## Repaso espaciado

Dos mecanismos, y ninguno es opcional. El olvido no es una hipótesis.

### 1. Dentro de cada módulo (7 días)

Todo módulo abre con **2–3 ejercicios cortos** (15 min en total) de módulos
anteriores, en `labs/00-repaso.md`. Se hacen **antes** del diagnóstico, en frío y
sin consultar notas. Es deliberado: si no te sale, acabas de encontrar el tema
para el repaso a 30 días.

### 2. Sesiones programadas (30 y 90 días)

Ocupan las semanas de reserva. Fuente: las columnas "comandos que tuve que
buscar" y "errores que cometí" de cada `NOTAS.md`, más `PREGUNTAS.md`.

| Cuándo | Semana | Repasa | Formato |
|---|---|---|---|
| 30 d | 7 | módulos 00–02 | Rehacer el break-fix de memoria, cronometrado |
| 30 d | 13 | módulos 05–07 | Ídem + preguntas de entrevista en voz alta |
| 90 d | 13 | módulos 00–02 | Levantar Pulse desde cero sin mirar el README |
| 30 d | 21 | módulos 08b–12 | Break-fix + explicar trade-offs |
| 90 d | 21 | módulos 05–08 | Reconstruir la capa de observabilidad de cero |
| 90 d | 28 | módulos 09–14 | Integrado en el Game Day II |

**La regla del repaso:** si tienes que abrir el README de un módulo que ya
cerraste, ese módulo no estaba cerrado. Marca su nivel a la baja en `TRACKER.md`
y programa una sesión extra. Bajar una nota propia es información, no fracaso.

---

## Niveles de contenido

Todo el contenido de cada módulo está etiquetado. Esto es lo que hace posible el
protocolo de atraso.

| Nivel | Qué es | ¿Se puede saltar? |
|---|---|---|
| **CORE** | Define el criterio de salida del módulo | **Nunca** |
| **EXTEND** | Profundidad adicional, casos borde | Sí, si hay atraso |
| **DEEP** | Exploración opcional | Sí, libremente |

---

## Protocolo de atraso

Un plan sin esto muere en el primer mes malo. Estas reglas se aplican solas: no
son una sugerencia para cuando tengas ganas de decidir.

### Vas 1 semana por detrás

No hagas nada. Para eso están las 4 semanas de reserva. Sigue el calendario.

### Vas 2 semanas por detrás

1. Elimina **todo el contenido EXTEND** del módulo actual y del siguiente.
2. Consume una semana de reserva.
3. **No elimines el break-fix.** Es el ejercicio con mayor retorno por minuto de
   todo el módulo, y es exactamente lo que se evalúa en entrevista.

### Vas 4 semanas por detrás

Modo compresión. En este orden:

1. Elimina EXTEND y DEEP de todos los módulos restantes.
2. Fusiona **15 en 16**: el Jenkinsfile se escribe como parte del Game Day y la
   comparativa se convierte en una sección del postmortem.
3. Convierte el módulo **14 en `plan`-only**: se valida el Terraform contra GCP
   con `terraform plan` y `gcloud ... --dry-run`, sin `apply`. Se documenta que
   no se ejecutó, igual que hiciste en el módulo 23 de `archive/`.
4. Mueve la fecha objetivo. **Mover la fecha es una decisión válida; fingir que
   completaste un módulo no lo es.**

### Vas más de 6 semanas por detrás

Para y replantea. Probablemente el problema no es el plan sino que 6 h/semana
dejaron de ser realistas. Reduce a 4 h/semana y recalcula, en vez de acumular
deuda y abandonar.

### Lo que no se salta nunca, en ningún escenario

- El **break-fix** de cada módulo.
- La **capa del capstone** — si te la saltas, el módulo siguiente no arranca.
- El **README de portafolio** — es el entregable, y escribirlo es la mitad del
  aprendizaje.

---

## Cómo es un bloque de 120 minutos

No es una sesión de lectura. Estructura sugerida:

| Min | Qué |
|---|---|
| 0–15 | Repaso corto del módulo anterior (`labs/00-repaso.md`), en frío |
| 15–95 | Trabajo del lab. Sin documentación abierta en el primer intento |
| 95–110 | La capa del capstone: dejar la plataforma desplegable |
| 110–120 | Rellenar `NOTAS.md` **mientras está fresco**, no después |

Los últimos 10 minutos son los que más se saltan y los que más valen. La columna
"errores que cometí" es la materia prima del repaso y de las respuestas de
entrevista.

### Regla del primer intento

En todo lab, el primer intento va **sin documentación**. Cuando te atasques,
anota qué buscaste antes de buscarlo. Esa lista es el mapa exacto de lo que aún
no dominas — y es lo que separa el criterio de salida "lo sé hacer" del criterio
"lo sé hacer sin ayuda".

---

## Estado de bloqueo

Si un lab te tiene bloqueado más de **45 minutos sin progreso medible**:

1. Escribe en `NOTAS.md` qué esperabas y qué observas. Con frecuencia esto lo
   resuelve solo.
2. Usa la siguiente pista escalonada del lab.
3. Si sigues bloqueado, **sáltalo y continúa**, marcándolo en `TRACKER.md`.
   Vuelve en la semana de reserva.

Atascarse tres horas en un problema de entorno no es perseverancia; es la forma
más común de abandonar un plan de estudios.
