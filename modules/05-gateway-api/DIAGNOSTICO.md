# Diagnóstico — Módulo 05

**Tiempo: 30 min.** Más corto que los demás a propósito.

## Aviso

Este es el único módulo donde **es normal suspender el diagnóstico**, incluso con
años de experiencia en Kubernetes. Gateway API no existe en ninguno de los repos
de labs de referencia y es relativamente reciente. Si lo suspendes, no significa
nada sobre tu nivel — significa que este módulo tiene 6 bloques por una razón.

Hazlo igualmente: sirve para medir dónde estás y para que el repaso a 30 días
sepa qué preguntar.

## Prueba

Sin documentación:

1. Nombra los tres recursos principales de Gateway API y di **qué rol
   organizativo** posee cada uno. La separación de roles es el motivo de que la
   API tenga esta forma.

2. Escribe un `HTTPRoute` que enrute `/api` a un Service `pulse-api:8080` y todo
   lo demás a `pulse-web:80`. De memoria.

3. Tienes un `HTTPRoute` que no recibe tráfico. `kubectl get httproute` muestra
   que existe. Nombra los **cuatro** sitios distintos donde puede estar el fallo
   y el comando que inspecciona cada uno.

4. ¿Qué puede hacer Gateway API que Ingress no puede hacer de forma portable?
   Da tres capacidades concretas.

5. Un compañero dice "hay que migrar, Ingress está deprecado". Corrígele con
   precisión.

## Criterio de aprobado

Las cinco. La 3 es la que de verdad importa: es la que vas a usar en producción.

## Resultado

- **Aprobado** → labs 00, 04 y 05, más el documento de migración. (3 bloques)
- **No aprobado** → módulo completo. (6 bloques)

## Nota sobre la pregunta 5

La respuesta correcta: Ingress **no está deprecado**. Está congelado en features
(estable en `networking.k8s.io/v1`, sin desarrollo nuevo) y Gateway API es su
sucesor designado. El problema real de Ingress no es que vaya a desaparecer, es
que expresar cualquier cosa más allá de enrutado por host y path requiere
anotaciones específicas del controlador, con lo que tu manifiesto deja de ser
portable.
