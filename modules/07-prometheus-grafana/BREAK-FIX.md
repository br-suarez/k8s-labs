# Break-fix — Módulo 07

## El escenario

Prometheus lleva tres semanas funcionando sin tocarlo. Desde el martes:

- Se reinicia solo cada 20–40 minutos.
- Los paneles de Grafana dan timeout o salen vacíos.
- Las alertas no dispararon durante una caída real ayer. Nadie se enteró hasta
  que lo reportó un cliente.

```
$ kubectl get pods -n monitoring
NAME                                READY   STATUS      RESTARTS      AGE
prometheus-kube-prometheus-0        1/2     CrashLoopBackOff   17 (2m ago)   23d

$ kubectl describe pod prometheus-kube-prometheus-0 -n monitoring | grep -A4 'Last State'
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Sat, 01 Aug 2026 09:14:22 +0000
      Finished:     Sat, 01 Aug 2026 09:51:03 +0000
```

Le subieron el límite de memoria de 2Gi a 6Gi el miércoles. Aguantó más tiempo
entre reinicios y luego volvió a lo mismo.

## Lo que cambió

`git log` del repo de manifiestos, el lunes:

```
commit 8f3a21c  "Add per-endpoint probe latency for the SRE dashboard"
```

```diff
- pulse_probe_duration_seconds{result="success"}
+ pulse_probe_duration_seconds{result="success", url="https://..."}
```

Y en el mismo commit, una regla de grabación "para acelerar el panel":

```yaml
- record: pulse:probe_duration:p99_by_url
  expr: histogram_quantile(0.99,
          sum by (le, url, result, region, check_id)
          (rate(pulse_probe_duration_seconds_bucket[5m])))
```

## Contexto que ya tienes

Pulse monitoriza **41.283 endpoints** para 340 clientes.

## Tu trabajo

1. Calcula, con números, cuántas series temporales generó ese cambio. Muestra la
   aritmética.
2. Explica por qué subir la memoria de 2Gi a 6Gi no lo arregló y qué habría
   pasado con 32Gi.
3. La regla de grabación se añadió para *acelerar* el panel. Explica por qué
   empeoró las cosas.
4. **Mitiga.** Prometheus está en CrashLoopBackOff ahora mismo y llevas dos días
   sin alertas. ¿Qué haces primero, en orden?
5. Arréglalo de forma que el equipo siga pudiendo investigar latencia por
   endpoint, porque esa necesidad era legítima.
6. ¿Qué control habría impedido que este commit llegara a producción?

## Pistas escalonadas

<details><summary>Pista 1</summary>

Un histograma de Prometheus no es una serie: es una serie **por bucket**, más
`_sum` y `_count`. Cuenta cuántos buckets tiene el histograma por defecto y
multiplica.
</details>

<details><summary>Pista 2</summary>

La cardinalidad de una métrica es el **producto** de los valores distintos de
todas sus etiquetas, no la suma. Ahora mira `sum by (le, url, result, region,
check_id)` en la regla de grabación y aplica lo mismo.
</details>

<details><summary>Pista 3 — para el punto 2</summary>

Prometheus mantiene en memoria un índice de todas las series activas y el bloque
head de las últimas dos horas. Ese consumo crece con el **número de series**, no
con el volumen de muestras. Subir el límite mueve el momento del OOM, no lo
evita, porque la ingesta sigue creando series nuevas.
</details>

<details><summary>Pista 4 — para el punto 4</summary>

No puedes consultar un Prometheus que no arranca, así que empieza por conseguir
que arranque, aunque sea sin datos. Piensa en qué le pasa al bloque head en
disco y qué flags de arranque existen para saltárselo.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

La explosión de cardinalidad es **el** fallo operativo de Prometheus. Y este
escenario tiene la propiedad que lo hace grave de verdad: durante dos días el
sistema que debía avisar de las caídas estaba caído, y nadie lo supo. Tu
observabilidad también necesita observabilidad.
