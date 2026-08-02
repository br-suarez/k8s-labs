# Diagnóstico — Módulo 04

**Tiempo: 45 min.** Sin documentación, sin `kubectl explain`, sin copiar
manifiestos previos.

## Parte A — desplegar (25 min)

Cluster vacío (`kind create cluster --config platform/deploy/clusters/lite.yaml`).
Escribe desde cero los manifiestos que dejen `pulse-api` corriendo con:

1. Deployment con 3 réplicas.
2. Service que lo alcance.
3. ConfigMap para la configuración no sensible, Secret para lo sensible, ambos
   consumidos como variables de entorno.
4. Liveness, readiness y startup probes, **cada una apuntando a lo correcto**.
5. Requests y limits que dejen los pods en QoS `Burstable`, a propósito.
6. `terminationGracePeriodSeconds` coherente con el drenaje real de la app.
7. Una estrategia de rolling update que garantice cero pods no disponibles.
8. HPA en `autoscaling/v2`.

Aplícalo y comprueba: 3 pods `Running`, `READY 1/1`, **0 restarts**, y el Service
respondiendo.

## Parte B — diagnosticar (20 min)

Sin ejecutar nada, responde:

1. Un pod lleva 5 minutos en `Pending`. Nombra las **tres clases** distintas de
   causa y el comando que distingue entre ellas.

2. Un Deployment reporta `3/3 READY` pero el Service devuelve 503 de forma
   intermitente. El endpoint de la app funciona si haces `port-forward` a
   cualquier pod. ¿Qué está pasando?

3. Aplicas un manifiesto y obtienes:
   ```
   error: resource mapping not found for name: "pulse-api" namespace: "pulse"
   from "hpa.yaml": no matches for kind "HorizontalPodAutoscaler" in version
   "autoscaling/v2beta2"
   ```
   ¿Qué pasó exactamente y cuál es el arreglo?

4. Una liveness probe mal configurada puede tumbar un servicio sano bajo carga.
   Explica el mecanismo.

## Criterio de aprobado

- Parte A: los 8 puntos, 0 restarts. El 4 y el 6 son los que separan.
- Parte B: las cuatro. La 4 es eliminatoria.

## Resultado

- **Aprobado** → labs 00, 02 y 04. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Nota

Tus módulos 01–12 de `archive/` cubren gran parte de la parte A. Lo que
probablemente no cubren es el punto 4 con las tres probes bien diferenciadas, ni
el 6. Si fallas solo esos, haz el lab 02 y sáltate el resto de la ruta remedial.
