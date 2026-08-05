# Diagnóstico — Módulo 10

**Tiempo: 35 min.** Sin documentación.

## Parte A — construir (20 min)

Cluster con Pulse corriendo. Sin usar `kubectl apply` para nada de la aplicación:

1. Instala Argo CD y accede a su API.
2. Estructura los manifiestos con Kustomize: una base y dos overlays, `dev` y
   `prod`, que difieran en réplicas, recursos y una variable de entorno. **Sin
   YAML duplicado.**
3. Una `Application` de Argo CD que despliegue el overlay `prod`.
4. Sync automático con self-heal y prune activados.
5. Borra a mano un Deployment de Pulse y comprueba que vuelve.

El punto 2 es el que separa. Casi todo el mundo acaba copiando el directorio
base y editándolo, que es exactamente lo que Kustomize existe para evitar.

## Parte B — razonar (15 min)

1. Argo dice `Synced` y `Healthy`. ¿Qué garantiza eso exactamente, y qué **no**
   garantiza? Da un caso concreto de aplicación rota con ambos en verde.

2. Una `Application` nunca alcanza `Synced`. El YAML en Git y el objeto en el
   cluster parecen idénticos. Tres causas posibles.

3. Son las 3am, hay una caída, y parcheas un Deployment a mano para restaurar el
   servicio. ¿Qué pasa en los siguientes tres minutos y por qué?

4. ¿Qué son las sync waves y en qué se diferencian de las dependencias entre
   recursos? Da un caso donde hagan falta.

5. Argo CD frente a Flux frente a `kubectl apply` desde CI. Un argumento a favor
   de cada uno.

## Criterio de aprobado

- Parte A: los 5 puntos, con el Deployment volviendo solo.
- Parte B: las cinco. **La 1 y la 3 son eliminatorias** — son el break-fix.

## Resultado

- **Aprobado** → labs 00, 04 y 06. (3 bloques)
- **No aprobado** → módulo completo. (5 bloques)

## Nota

El módulo 21 de `archive/sre-track/` usa Argo CD, pero para canary. Lo que este
módulo añade es el modelo operativo: qué significa que el cluster sea una
consecuencia del repositorio, y qué pasa cuando un humano necesita saltárselo.
