# Break-fix — Módulo 04

## El escenario

Despliegue rutinario de `pulse-api` a las 11:04. Nada especial: un cambio de
texto en un log.

Entre las 11:04 y las 11:06, el 15% de las peticiones fallan con 502 y 503.
A las 11:06:30 todo vuelve a la normalidad sin que nadie toque nada.

Esto pasa **en cada despliegue**. El equipo ha aprendido a desplegar "cuando hay
poco tráfico" y nadie ha investigado por qué.

## Lo que ves cuando llegas

```
$ kubectl get pods -n pulse
NAME                         READY   STATUS    RESTARTS   AGE
pulse-api-7d4f9c6b8-2xkqp    1/1     Running   0          4m
pulse-api-7d4f9c6b8-8vmnw    1/1     Running   0          4m
pulse-api-7d4f9c6b8-jf3rt    1/1     Running   0          4m

$ kubectl get events -n pulse --sort-by=.lastTimestamp | tail -5
4m   Normal   ScalingReplicaSet   deployment/pulse-api   Scaled up replica set pulse-api-7d4f9c6b8 to 3
4m   Normal   ScalingReplicaSet   deployment/pulse-api   Scaled down replica set pulse-api-5b8d7f4a9 to 0
```

Sin restarts. Sin OOMKilled. Sin eventos de error. Todos los pods sanos.

El fragmento relevante del Deployment:

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 3
      maxUnavailable: 0
  template:
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: pulse-api
          image: ghcr.io/example/pulse-api:v1.4.2
          ports:
            - containerPort: 8080
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            periodSeconds: 5
```

## Pista de contexto que ya tienes

`pulse-api` expone dos endpoints distintos, y no hacen lo mismo:

- `/healthz` → devuelve 200 en cuanto el proceso levanta el servidor HTTP.
- `/readyz` → devuelve **503 durante los primeros 2 segundos**, y 200 después.

Lo puedes confirmar en
[`platform/services/pulse-api/main.go`](../../platform/services/pulse-api/main.go).

## Tu trabajo

1. Explica exactamente por qué fallan peticiones si todos los pods están sanos y
   ninguno reinicia.
2. Calcula cuántas peticiones deberían fallar aproximadamente, dado el ritmo de
   despliegue y la ventana de no-readiness. ¿Cuadra con el 15% observado?
3. Hay **dos** problemas independientes en ese manifiesto que contribuyen. El
   segundo no es la probe.
4. Arréglalos. Demuestra con una prueba de carga durante un despliegue que el
   error baja a cero.
5. La liveness probe también está mal configurada de una forma que todavía no ha
   causado un incidente. Encuéntrala y explica bajo qué condiciones explotaría.

## Pistas escalonadas

<details><summary>Pista 1</summary>

Lee las dos probes otra vez y compáralas con lo que hace cada endpoint. ¿Qué
pregunta responde una readiness probe, y está esta probe respondiéndola?
</details>

<details><summary>Pista 2</summary>

Un pod entra en los Endpoints del Service en cuanto su readiness probe pasa. Si
esa probe pasa antes de que la aplicación pueda servir de verdad, ¿a dónde va el
tráfico?
</details>

<details><summary>Pista 3 — para el punto 3</summary>

`maxSurge: 3` con `replicas: 3`. ¿Cuántos pods nuevos aparecen a la vez? Ahora
piensa qué pasa cuando los tres entran en los Endpoints simultáneamente y
ninguno está listo de verdad.
</details>

<details><summary>Pista 4 — para el punto 5</summary>

La liveness probe apunta a `/healthz` con `periodSeconds: 10` y el
`failureThreshold` por defecto. Imagina que la app se degrada bajo carga y
`/healthz` empieza a tardar más que el `timeoutSeconds` por defecto. ¿Qué hace
Kubernetes, y qué le pasa a la carga que atendían esos pods?
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Es el fallo de Kubernetes más común que existe y el que peor se diagnostica,
porque **todos los indicadores están verdes**. `kubectl get pods` no te va a
ayudar. Hay que entender el modelo, no leer el estado.
