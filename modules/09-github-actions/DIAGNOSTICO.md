# Diagnóstico — Módulo 09

**Tiempo: 35 min.** Sin documentación.

## Parte A — escribir (20 min)

Desde un archivo en blanco, escribe `.github/workflows/ci.yml` que:

1. Se dispare en push a `main` y en pull request.
2. Construya `pulse-api`, ejecute tests y `go vet`.
3. Cachee dependencias de forma que un cambio de código **no** invalide la caché.
4. Construya la imagen y la publique en GHCR **por digest**, nunca por tag mutable.
5. Genere un SBOM y lo adjunte como artefacto.
6. Falle si hay vulnerabilidades HIGH, con una vía documentada de excepción.
7. Use permisos mínimos — nada de `permissions: write-all`.
8. Impida que dos ejecuciones sobre `main` corran a la vez.

El 7 y el 8 son los que separan. El 8 casi nadie lo pone hasta que le muerde.

## Parte B — razonar (15 min)

1. `pull_request` vs `pull_request_target`. ¿Por qué el segundo es peligroso y en
   qué caso concreto lo necesitas de todas formas?

2. Tu pipeline construye una imagen, la prueba, y despliega. Todo verde. En
   producción corre **una imagen distinta a la que se probó**. ¿Cómo puede pasar?
   Da dos mecanismos.

3. `GITHUB_TOKEN` vs un PAT vs OIDC hacia un proveedor cloud. ¿Cuál usas para
   desplegar a GCP y por qué los otros dos son peores?

4. Un job restaura una caché que alimenta el build. Explica cómo un PR desde un
   fork podría envenenarla, y qué lo impide.

## Criterio de aprobado

- Parte A: los 8 requisitos.
- Parte B: las cuatro. **La 2 es eliminatoria** — es el break-fix de este módulo.

## Resultado

- **Aprobado** → labs 00, 04 y 05. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Nota

El módulo 30 de `archive/sre-track/` cubre la puerta de despliegue. Lo que
probablemente no cubre: la concurrencia, el modelo de permisos, y la pregunta 2 —
que es donde el pipeline miente estando verde.
