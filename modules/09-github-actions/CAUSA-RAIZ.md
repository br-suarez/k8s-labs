# Causa raíz — Módulo 09

> Solo después de haber dibujado la línea de tiempo.

## 1. La secuencia del viernes

```
t=0    Merge PR #411 → ejecución A arranca
t=5s   Merge PR #412 → ejecución B arranca (en paralelo, nada lo impide)

t=90s  A: build termina.  push ghcr.io/.../pulse-api:latest → digest AAA
t=95s  B: build termina.  push ghcr.io/.../pulse-api:latest → digest BBB
                          ↑ el tag `latest` ahora apunta a BBB

t=120s A: test hace pull de :latest  →  se trae BBB   ← prueba el artefacto de B
t=125s B: test hace pull de :latest  →  se trae BBB   ← correcto por casualidad

t=160s A: deploy → kubectl set image :latest
t=165s B: deploy → kubectl set image :latest
                   ↑ mismo string, Kubernetes no ve ningún cambio

t=170s A: rollout restart → los nodos hacen pull de :latest → BBB
```

**El arreglo del PR #411 (digest AAA) se construyó, se publicó, y quedó
huérfano.** Nunca se probó y nunca se desplegó. Su tag se lo llevó B cinco
segundos después.

Y lo perverso: el que se perdió fue el de la ejecución que terminó **primero**.
No hay intuición que te lleve ahí.

## 2. Por qué nada falló

Cada job hizo exactamente lo que se le pidió:

- `build` construyó desde su propio commit y empujó. Correcto.
- `test` hizo pull de `:latest` y lo probó. **Nadie le dijo qué digest esperar**,
  así que probó lo que había. Pasó, porque BBB era una imagen perfectamente
  buena.
- `deploy` puso la imagen `:latest`. Correcto según lo escrito.

No hay ningún punto donde el sistema pudiera detectar el problema, porque **el
pipeline nunca supo qué artefacto estaba manejando**. Manejó un nombre, no una
cosa.

## 3. ¿Probó `test` lo que construyó su ejecución?

No, y **no había forma de saberlo**. Esa es la respuesta correcta al punto 3, y
es más importante que el bug concreto: un pipeline que no puede responder "¿qué
artefacto exacto validé?" no está validando nada de forma verificable.

## 4. Los tres defectos

### a) Sin control de concurrencia

Nada impide que dos ejecuciones sobre `main` corran a la vez.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false
```

`cancel-in-progress: false` a propósito: en `main` quieres que ambas terminen en
serie, no cancelar la primera. En ramas de PR sí quieres `true`, para no gastar
runners en commits ya superados.

### b) Tag mutable como identidad del artefacto

`:latest` es un puntero compartido y modificable. Es exactamente la lección del
módulo 03, cobrada.

```yaml
tags: |
  ghcr.io/${{ github.repository_owner }}/pulse-api:${{ github.sha }}
  ghcr.io/${{ github.repository_owner }}/pulse-api:latest
```

El tag por SHA es inmutable en la práctica. `latest` puede seguir existiendo para
comodidad humana, pero **nada automatizado debe consumirlo**.

### c) El digest no viaja entre jobs

`build` conoce el digest exacto que produjo. `test` y `deploy` no lo reciben.

```yaml
jobs:
  build:
    outputs:
      digest: ${{ steps.push.outputs.digest }}
    steps:
      - id: push
        uses: docker/build-push-action@v6
        # ...

  test:
    needs: build
    steps:
      - run: ./scripts/smoke-test.sh "ghcr.io/${OWNER}/pulse-api@${{ needs.build.outputs.digest }}"
```

Con esto, `test` prueba el artefacto de **su** ejecución, siempre, y `deploy`
despliega ese mismo. El digest es la cadena de custodia.

## 5. El pipeline corregido

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    outputs:
      digest: ${{ steps.push.outputs.digest }}
      image: ghcr.io/${{ github.repository_owner }}/pulse-api
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: push
        uses: docker/build-push-action@v6
        with:
          context: ./platform/services/pulse-api
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/pulse-api:${{ github.sha }}
            ghcr.io/${{ github.repository_owner }}/pulse-api:latest

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      # Por digest: irrepetible, inmutable, imposible de confundir
      - run: ./scripts/smoke-test.sh "${{ needs.build.outputs.image }}@${{ needs.build.outputs.digest }}"

  deploy:
    needs: [build, test]
    runs-on: ubuntu-latest
    steps:
      - run: |
          kubectl set image deployment/pulse-api \
            pulse-api="${{ needs.build.outputs.image }}@${{ needs.build.outputs.digest }}" \
            -n pulse
          kubectl rollout status deployment/pulse-api -n pulse --timeout=5m
```

Cambios que importan: `concurrency`, digest como salida del job, referencias por
digest en `test` y `deploy`, y `rollout status` en vez de `restart` — porque
ahora la imagen **sí** cambia, así que Kubernetes hace el rollout solo y puedes
esperar a que termine y fallar si no converge.

## 6. El problema adicional de `rollout restart` con `:latest`

`kubectl set image` con el mismo string no cambia nada en el spec, así que
Kubernetes no despliega. De ahí que hiciera falta `rollout restart` — que fuerza
pods nuevos **sin que el spec haya cambiado**.

Consecuencia: cada nodo hace su propio pull de `:latest` en el momento en que
arranca su pod. Si dos nodos hacen pull en momentos distintos y el tag se movió
en medio, **acabas con réplicas del mismo Deployment corriendo imágenes
distintas**, y `kubectl get deployment -o yaml` te dirá que todo está correcto.

Cómo verlo:

```bash
kubectl get pods -n pulse -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].imageID}{"\n"}{end}' | sort -k2 -u
```

Si esa consulta devuelve más de un digest para el mismo Deployment, tienes una
flota partida. Es un comando que conviene memorizar.

Con referencias por digest esto es imposible por construcción: el spec cambia,
el rollout ocurre solo, y todos los nodos traen exactamente el mismo artefacto.
