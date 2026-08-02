# Diagnóstico — Módulo 03

**Tiempo: 40 min.** Sin documentación, sin plantillas, sin copiar un Dockerfile
anterior.

## Parte A — construir (25 min)

Escribe desde cero un `Dockerfile` multi-stage para `pulse-api` que produzca una
imagen que:

1. Pese menos de 25 MB.
2. Corra como usuario no-root.
3. No contenga shell, gestor de paquetes ni compilador.
4. Pueda hacer peticiones HTTPS salientes correctamente.
5. Reciba señales correctamente (`docker stop` en menos de 2 s, no 10).
6. Reconstruya en menos de 5 s tras cambiar una línea de `main.go`.
7. Declare un `HEALTHCHECK` que compruebe readiness, no liveness.

Verifica cada punto con un comando, no de vista.

**Los puntos 4 y 5 son los que separan.** El 4 falla de una forma que no vas a
notar hasta que el contenedor intente hablar con el exterior.

## Parte B — razonar (15 min)

1. Tienes dos Dockerfiles idénticos salvo el orden de dos instrucciones. Uno
   reconstruye en 2 s tras un cambio de código y el otro en 90 s. Explica el
   mecanismo, no solo la regla.

2. `docker pull app:v1.2.3` en dos máquinas devuelve imágenes con digests
   distintos. ¿Es posible? ¿Qué implica para tu estrategia de despliegue?

3. Un contenedor arranca, funciona 10 s y muere sin logs. `docker logs` está
   vacío. Da tu secuencia de diagnóstico y qué descarta cada paso.

## Criterio de aprobado

- Parte A: los 7 puntos verificados con comandos.
- Parte B: las tres. La 2 es eliminatoria — si respondes que no es posible, no
  has entendido qué es un tag.

## Resultado

- **Aprobado** → labs 00, 03 y 05. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Nota

Si vienes del módulo 25 de `archive/sre-track/`, la parte A debería salirte casi
entera. El punto 4 probablemente no — es el fallo clásico de distroless y solo se
aprende habiéndolo sufrido.
