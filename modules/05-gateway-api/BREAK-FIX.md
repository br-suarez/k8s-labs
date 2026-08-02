# Break-fix — Módulo 05

## El escenario

Migración de Ingress a Gateway API terminada el viernes. El lunes por la mañana,
el dashboard de Pulse devuelve **404 desde el gateway** para todo excepto `/api`,
que funciona perfectamente.

En staging funcionaba todo. La diferencia entre staging y producción: en
producción, `pulse-web` vive en un namespace distinto (`pulse-frontend`) porque lo
gestiona otro equipo.

## Lo que ves

```
$ kubectl get gateway,httproute -A
NAMESPACE   NAME                              CLASS    ADDRESS        PROGRAMMED   AGE
pulse       gateway.../pulse-gateway          envoy    10.96.42.17    True         3d

NAMESPACE        NAME                         HOSTNAMES              AGE
pulse            httproute.../pulse-api       ["pulse.example.com"]  3d
pulse-frontend   httproute.../pulse-web       ["pulse.example.com"]  3d
```

Los dos HTTPRoutes existen. El Gateway está `PROGRAMMED: True`.

```
$ curl -s -o /dev/null -w '%{http_code}\n' https://pulse.example.com/api/checks
200
$ curl -s -o /dev/null -w '%{http_code}\n' https://pulse.example.com/
404
```

El Service existe y funciona:

```
$ kubectl get svc pulse-web -n pulse-frontend
NAME        TYPE        CLUSTER-IP     PORT(S)
pulse-web   ClusterIP   10.96.88.104   80/TCP

$ kubectl run t --rm -it --image=busybox --restart=Never -- \
    wget -qO- http://pulse-web.pulse-frontend:80/ | head -2
<!doctype html>
```

## El manifiesto de `pulse-web`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: pulse-web
  namespace: pulse-frontend
spec:
  parentRefs:
    - name: pulse-gateway
      namespace: pulse
  hostnames:
    - pulse.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: pulse-web
          port: 80
```

Y el Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: pulse-gateway
  namespace: pulse
spec:
  gatewayClassName: envoy
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: pulse.example.com
      tls:
        certificateRefs:
          - name: pulse-tls
      allowedRoutes:
        namespaces:
          from: Same
```

## Tu trabajo

1. **No mires los manifiestos todavía.** ¿Cuál es el primer comando que
   ejecutarías? Gateway API te dice qué pasa si sabes dónde mirar.
2. Hay **dos** problemas independientes que impiden que ese route funcione.
   Encuentra los dos. Arreglar solo uno no soluciona nada, y eso es parte de la
   dificultad.
3. Arréglalos.
4. Explica por qué el equipo de `pulse-web` no puede arreglar esto por sí solo, y
   por qué eso es un rasgo de diseño de Gateway API y no un defecto.
5. ¿Por qué funcionaba en staging?

## Pistas escalonadas

<details><summary>Pista 1</summary>

Gateway API es declarativo con estado rico. Todo recurso lleva `status.parents[]`
con condiciones. `kubectl describe httproute pulse-web -n pulse-frontend` te dice
literalmente qué falla, con motivo y mensaje. Empieza siempre por ahí — no por
los logs del controlador.
</details>

<details><summary>Pista 2</summary>

Busca dos condiciones distintas en el status: una sobre si el Gateway **aceptó**
el route, y otra sobre si las **referencias a backends** se resolvieron. Pueden
fallar de forma independiente, y aquí fallan las dos.
</details>

<details><summary>Pista 3 — problema A</summary>

`allowedRoutes.namespaces.from: Same`. El Gateway está en `pulse`. El route está
en `pulse-frontend`. ¿Los considera el Gateway "el mismo namespace"?
</details>

<details><summary>Pista 4 — problema B</summary>

Aunque el Gateway aceptara el route, el `backendRefs` apunta a un Service. ¿En
qué namespace busca ese Service? ¿Y qué recurso hace falta para que una
referencia cruce un límite de namespace de forma autorizada?
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Es el fallo número uno al adoptar Gateway API, y enseña lo que hace a esta API
distinta: **no tienes que adivinar**. Con Ingress, un route que no funciona te
obliga a leer logs del controlador. Aquí el objeto te dice qué pasa en su propio
`status`, y aprender a leerlo es la mitad del módulo.
