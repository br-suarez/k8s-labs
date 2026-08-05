# Break-fix — Módulo 09

## El escenario

Viernes por la tarde. Dos PRs se aprueban con un minuto de diferencia y ambos se
mergean a `main`.

El pipeline corre dos veces, en paralelo. **Ambas ejecuciones salen en verde.**
Los tests pasan, el escaneo pasa, la puerta de despliegue pasa.

El lunes, un cliente reporta un bug que se supone que el PR #412 arregló. Miras
producción: el arreglo no está. Miras el pipeline: verde. Miras `main`: el
commit está ahí, mergeado el viernes.

```
$ kubectl get deployment pulse-api -n pulse -o jsonpath='{.spec.template.spec.containers[0].image}'
ghcr.io/br-suarez/pulse-api:latest

$ kubectl get pods -n pulse -o jsonpath='{.items[0].status.containerStatuses[0].imageID}'
ghcr.io/br-suarez/pulse-api@sha256:9f2c4a...

$ gh api /user/packages/container/pulse-api/versions -q '.[0:3] | .[] | "\(.metadata.container.tags) \(.name[0:20])"'
["latest"]  sha256:9f2c4a1b8e3d7f0a
[]          sha256:c7d1e59f2a4b8c30
```

Dos digests. El más reciente en el registro **no** es el que tiene el tag
`latest`.

## El workflow

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: ./platform/services/pulse-api
          push: true
          tags: ghcr.io/${{ github.repository_owner }}/pulse-api:latest

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: |
          docker pull ghcr.io/${{ github.repository_owner }}/pulse-api:latest
          ./scripts/smoke-test.sh ghcr.io/${{ github.repository_owner }}/pulse-api:latest

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: |
          kubectl set image deployment/pulse-api \
            pulse-api=ghcr.io/${{ github.repository_owner }}/pulse-api:latest -n pulse
          kubectl rollout restart deployment/pulse-api -n pulse
```

## Tu trabajo

1. Reconstruye la secuencia exacta de eventos del viernes. Dibuja la línea de
   tiempo de las dos ejecuciones y di en qué instante se pierde el arreglo.
2. ¿Por qué **ninguna** de las dos ejecuciones falló? Sé preciso: cada job hizo
   exactamente lo que se le pidió.
3. El job `test` probó una imagen. ¿Era la que construyó su propia ejecución?
   ¿Puedes estar seguro?
4. Hay **tres** defectos distintos aquí. Encuéntralos.
5. Arréglalo. Debe ser imposible que el pipeline pruebe una imagen y despliegue
   otra.
6. `kubectl rollout restart` con el tag `latest` — ¿qué problema adicional
   introduce que no tiene que ver con la concurrencia?

## Pistas escalonadas

<details><summary>Pista 1</summary>

Dos ejecuciones en paralelo escribiendo el **mismo tag mutable**. Ya viste en el
módulo 03 que un tag es un puntero, no una identidad. ¿Qué pasa si dos procesos
mueven el mismo puntero?
</details>

<details><summary>Pista 2</summary>

Los jobs `build`, `test` y `deploy` están en máquinas distintas y se comunican
solo por el registro. Entre que `build` empuja y `test` hace `pull`, pasa tiempo.
¿Quién garantiza que nadie escribió ese tag en medio?
</details>

<details><summary>Pista 3 — para el punto 4</summary>

Busca: (a) qué falta en el `on:` para que dos ejecuciones no se pisen, (b) qué
falta en el `tags:` para que el artefacto sea identificable, y (c) qué falta
entre `build` y `test` para que el segundo sepa exactamente qué probar.
</details>

<details><summary>Pista 4 — para el punto 6</summary>

`imagePullPolicy` con el tag `latest`. ¿Qué hace cada nodo cuando arrancas un pod
nuevo? ¿Y si dos nodos hicieron pull en momentos distintos?
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Es el fallo que hace que la gente deje de confiar en su CI, y es especialmente
insidioso porque **el pipeline no miente: hace exactamente lo que le pediste**.
El error está en lo que le pediste, y todos los indicadores están en verde
mientras ocurre.
