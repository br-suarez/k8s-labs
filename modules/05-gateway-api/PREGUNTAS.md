# Preguntas de entrevista — Módulo 05

## Modelo y roles

**1. Los tres recursos principales y el rol que posee cada uno. ¿Por qué está
diseñada así?**

<details><summary>Guía</summary>

`GatewayClass` (infrastructure provider — quién implementa), `Gateway` (cluster
operator — dónde y cómo se expone, TLS, qué routes se admiten), `HTTPRoute`
(application developer — cómo se enruta *mi* servicio). El diseño separa
responsabilidades que Ingress mezcla en un solo objeto: con Ingress, cambiar el
enrutado de tu aplicación te obliga a editar un recurso que también contiene la
configuración TLS y las anotaciones del controlador, que no son tuyas.
</details>

**2. "Ingress está deprecado." Corrige la frase.**

<details><summary>Guía</summary>

No lo está. Es estable en `networking.k8s.io/v1` y está **congelado en features**:
se mantiene, no se le añade nada. Gateway API es el sucesor designado. El problema
real no es la desaparición sino la portabilidad — cualquier cosa más allá de host
y path requiere anotaciones específicas del controlador, así que un manifiesto de
Ingress no trivial no se mueve entre implementaciones.
</details>

**3. Tres cosas que Gateway API hace de forma portable y Ingress no.**

<details><summary>Guía</summary>

Reparto de tráfico por peso (la base del canary del módulo 11); enrutado por
cabecera, método y query; enrutado entre namespaces con autorización explícita
vía `ReferenceGrant`; espejado de peticiones; filtros de request/response
tipados. Todo eso existe en Ingress solo mediante anotaciones propietarias.
</details>

## Depuración

**4. Un HTTPRoute no recibe tráfico. Los cuatro sitios donde puede estar el
fallo.**

<details><summary>Guía</summary>

(a) El route no se enganchó al Gateway — condición `Accepted`, típicamente
`NotAllowedByListeners` por `allowedRoutes`. (b) Los backendRefs no resuelven —
condición `ResolvedRefs`, `RefNotPermitted` (falta `ReferenceGrant`) o
`BackendNotFound`. (c) El `parentRef` no coincide: nombre, namespace o
`sectionName` equivocados. (d) Hostname: el del route no intersecta con el del
listener. Todo se lee en `status.parents[].conditions` — el primer comando es
`kubectl describe httproute`, nunca los logs del controlador.
</details>

**5. `allowedRoutes` y `ReferenceGrant` — ¿qué autoriza cada uno y por qué hacen
falta los dos?**

<details><summary>Guía</summary>

`allowedRoutes` lo concede el dueño del Gateway: qué routes pueden engancharse.
`ReferenceGrant` lo concede el dueño del backend: quién puede enviar tráfico a mi
Service. Son controles en direcciones opuestas y ninguno implica al otro. El
diseño es deliberado: ningún equipo puede unilateralmente exponer el servicio de
otro ni secuestrar el gateway de otro.
</details>

**6. `Gateway` en `PROGRAMMED: True` — ¿qué garantiza y qué no?**

<details><summary>Guía</summary>

Garantiza que el controlador tradujo la configuración a su plano de datos y este
la aceptó. No garantiza que ningún route esté enganchado, que los backends
existan, ni que el tráfico llegue. Un Gateway perfectamente programado sin
ningún route válido devuelve 404 a todo, que es exactamente el escenario del
break-fix.
</details>

## Precedencia y semántica

**7. Dos HTTPRoutes con hostname `app.example.com`: uno con `PathPrefix /` y otro
con `PathPrefix /api`. ¿Cuál gana para `/api/checks`? ¿Y cómo se decide si
empatan?**

<details><summary>Guía</summary>

Gana `/api`: la precedencia está **especificada**, no depende del orden de
creación ni del controlador. El orden es match exacto antes que prefijo, prefijo
más largo antes que más corto, luego número de cabeceras coincidentes, luego
query params. Si sigue habiendo empate, gana el objeto con `creationTimestamp`
más antiguo, y en último extremo el orden alfabético de namespace/nombre. Esta
determinación es una diferencia real frente a NGINX Ingress, donde la
precedencia depende de cómo el controlador ordena las reglas regex.
</details>

**8. ¿Diferencia entre canal standard y experimental? ¿Cuál es el riesgo de
depender del experimental?**

<details><summary>Guía</summary>

Standard contiene recursos y campos GA con garantías de compatibilidad;
experimental incluye features en desarrollo que pueden cambiar de forma
incompatible o desaparecer entre versiones menores. A partir de v1.4–v1.6, la
mayoría de lo interesante ya está en standard —`GRPCRoute`, `TCPRoute`,
`TLSRoute`, `UDPRoute`, `ReferenceGrant` y `BackendTLSPolicy` están todos en `v1`
en el canal standard—, así que la necesidad de experimental es hoy mucho menor
que hace dos años. Instalar los CRDs experimentales en un cluster de producción
convierte una actualización menor en un riesgo de rotura.
</details>

## Trade-offs

**9. Defiende Gateway API frente a Ingress con anotaciones y frente a una service
mesh.**

<details><summary>Guía</summary>

Frente a Ingress: portabilidad y separación de roles; el coste es más objetos y
una curva de aprendizaje mayor — para un cluster de un solo equipo con enrutado
trivial, Ingress sigue siendo defendible. Frente a una mesh: Gateway API es
tráfico norte-sur; una mesh añade este-oeste, mTLS entre servicios y
observabilidad por salto, a cambio de un sidecar o un componente por nodo y una
complejidad operativa considerable. Nota que convergen: GAMMA extiende Gateway
API al tráfico este-oeste, así que la elección cada vez es menos excluyente.
</details>

**10. Vas a migrar 200 Ingresses. ¿Cómo lo planteas?**

<details><summary>Qué se evalúa</summary>

Que no digas "conversión automática y listo". Lo que se busca: inventariar
primero las anotaciones en uso —ahí está el trabajo real, no en el host/path—,
identificar cuáles no tienen equivalente en Gateway API, correr ambos en
paralelo con el mismo hostname y desviar tráfico progresivamente, y tener un plan
de rollback. Y reconocer que algunas anotaciones no se van a poder migrar y
requerirán decisiones de producto, no técnicas.
</details>
