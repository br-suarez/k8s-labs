# Causa raíz — Módulo 05

> Solo después de haber escrito tu diagnóstico.

## El comando que resuelve el 80% del caso

```bash
kubectl describe httproute pulse-web -n pulse-frontend
```

```
Status:
  Parents:
    Conditions:
      Type:     Accepted
      Status:   False
      Reason:   NotAllowedByListeners
      Message:  No listeners included by this parent ref allowed this attachment
```

El objeto te dice el problema, con un `Reason` que es una constante documentada.
Esto es la diferencia práctica más grande frente a Ingress, donde el mismo fallo
solo aparece —si aparece— en los logs del controlador.

## Problema A — `allowedRoutes.namespaces.from: Same`

```yaml
allowedRoutes:
  namespaces:
    from: Same          # ← solo routes del namespace del Gateway
```

El Gateway está en `pulse`. El HTTPRoute está en `pulse-frontend`. `Same`
significa literalmente el mismo namespace, así que el listener rechaza el
attachment.

**Esto es intencionado.** Es el control que impide que cualquiera con permisos en
cualquier namespace se enganche a tu gateway de producción y secuestre una ruta.
`Same` es el valor por defecto seguro.

### El arreglo

```yaml
allowedRoutes:
  namespaces:
    from: Selector
    selector:
      matchLabels:
        gateway-access: pulse-prod
```

Y en el namespace:

```bash
kubectl label namespace pulse-frontend gateway-access=pulse-prod
```

`from: All` también funciona y es lo que casi todo el mundo pone al frustrarse.
No lo hagas: acabas de convertir tu gateway en un recurso que cualquier namespace
del cluster puede reclamar.

## Problema B — falta el `ReferenceGrant`

Aunque el Gateway acepte el route, aparece la segunda condición:

```
      Type:     ResolvedRefs
      Status:   False
      Reason:   RefNotPermitted
      Message:  Backend ref to Service pulse/pulse-web not permitted by any ReferenceGrant
```

Detalle importante: `backendRefs` sin `namespace` explícito resuelve **en el
namespace del HTTPRoute**, no en el del Gateway. Y si lo pones explícito para
apuntar a otro namespace, necesitas autorización del lado del destino.

Toda referencia que cruza un namespace en Gateway API requiere un
`ReferenceGrant` **creado en el namespace de destino**. El sentido es que el
dueño del recurso destino consiente ser referenciado — no basta con que el
solicitante lo pida.

### El arreglo

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-pulse-routes
  namespace: pulse-frontend      # ← donde vive el Service destino
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: pulse
  to:
    - group: ""
      kind: Service
      name: pulse-web
```

En este caso concreto, como el HTTPRoute y el Service están ambos en
`pulse-frontend`, el `ReferenceGrant` solo hace falta si decides mover el route a
`pulse`. Que es exactamente la decisión del punto 4.

## Por qué hacen falta los dos arreglos

Son controles **independientes** en direcciones opuestas:

| Control | Quién lo concede | Qué autoriza |
|---|---|---|
| `allowedRoutes` | El dueño del **Gateway** | Qué routes pueden engancharse a mi gateway |
| `ReferenceGrant` | El dueño del **backend** | Quién puede mandar tráfico a mi Service |

Arreglar solo uno deja el otro bloqueando. Y esa es la respuesta al punto 4: el
equipo de `pulse-web` **no puede** arreglarlo solo, porque `allowedRoutes` vive
en el Gateway, que pertenece al equipo de plataforma.

Eso no es un defecto: es el modelo de roles de Gateway API funcionando. Ingress
mezcla las tres responsabilidades en un objeto que normalmente edita cualquiera
con acceso al namespace.

| Rol | Recurso | Quién |
|---|---|---|
| Infrastructure provider | `GatewayClass` | El proveedor del cluster |
| Cluster operator | `Gateway` | El equipo de plataforma |
| Application developer | `HTTPRoute` | El equipo del servicio |

## Por qué funcionaba en staging

En staging, `pulse-web` estaba en el namespace `pulse`, junto al Gateway. Con
`from: Same` y sin cruce de namespaces, ninguno de los dos controles se activaba.

**La lección real:** la diferencia entre staging y producción no era la
configuración de Gateway API, era la **topología de namespaces**. Un entorno de
staging que no reproduce los límites de namespace de producción no valida nada
sobre enrutado entre equipos — y ese tipo de diferencia estructural es la que
produce incidentes de lunes por la mañana.

## Cómo verificarlo, siempre

```bash
# Las dos condiciones que importan, de un vistazo
kubectl get httproute -A -o custom-columns=\
'NS:.metadata.namespace,NAME:.metadata.name,ACCEPTED:.status.parents[0].conditions[?(@.type=="Accepted")].status,RESOLVED:.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status'
```

Guarda ese comando. Es el `kubectl get endpoints` de Gateway API: el primero que
ejecutas cuando algo no enruta.
