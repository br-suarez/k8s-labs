# Preguntas de entrevista — Módulo 09

## Identidad del artefacto

**1. Tu pipeline construye, prueba y despliega. Todo verde. En producción corre
una imagen distinta a la probada. ¿Cómo?**

<details><summary>Guía</summary>

Dos mecanismos. (a) El pipeline referencia un **tag mutable**: otra ejecución
concurrente mueve el tag entre el push y el pull, así que `test` valida un
artefacto y `deploy` despliega otro. (b) `imagePullPolicy: Always` con un tag
mutable: cada nodo resuelve el tag en el momento de arrancar su pod, y nodos que
arrancan en momentos distintos pueden traer digests distintos — flota partida
dentro del mismo Deployment. La respuesta a ambos es la misma: referenciar por
digest, y hacer que el digest viaje entre jobs.
</details>

**2. ¿Cómo compruebas, ahora mismo, que todos los pods de un Deployment corren la
misma imagen?**

<details><summary>Guía</summary>

`kubectl get pods -o jsonpath='{range .items[*]}{.status.containerStatuses[0].imageID}{"\n"}{end}' | sort -u`.
`imageID` es el **digest realmente en ejecución**, no el tag pedido. Más de una
línea significa flota partida. `kubectl get deployment -o yaml` no lo detecta,
porque el spec es uno solo y es correcto.
</details>

## Concurrencia y disparadores

**3. ¿Qué hace `concurrency` y por qué `cancel-in-progress` debería ser distinto
en `main` que en un PR?**

<details><summary>Guía</summary>

Serializa ejecuciones que comparten un grupo. En un PR quieres `true`: un commit
nuevo invalida el anterior y no tiene sentido gastar runners. En `main` quieres
`false`: cada commit debe construirse, probarse y desplegarse, y cancelar el
primero deja un commit sin artefacto. Sin `concurrency`, dos merges cercanos se
pisan — el break-fix de este módulo.
</details>

**4. `pull_request` vs `pull_request_target`. ¿Por qué el segundo es peligroso?**

<details><summary>Guía</summary>

`pull_request` corre en el contexto del fork: sin secretos y con token de solo
lectura, por eso es seguro. `pull_request_target` corre en el contexto del **repo
base**, con secretos y token de escritura, pero se dispara por PRs de
desconocidos. Si además haces checkout del código del PR, estás ejecutando código
arbitrario de un extraño con tus secretos — vector de exfiltración conocido y
explotado. Se necesita cuando hay que etiquetar o comentar el PR; en ese caso
nunca se hace checkout del head del PR.
</details>

**5. ¿Cómo envenena un fork la caché de tu build?**

<details><summary>Guía</summary>

Un job de PR guarda una caché que luego restaura un job de `main`. GitHub aísla
cachés por rama con reglas de alcance —una rama lee de sí misma y de la rama base
por defecto—, pero un flujo mal diseñado puede dejar que contenido de un PR
llegue a una caché consumida por builds de confianza. La mitigación: nunca
cachear artefactos ejecutables cruzando límites de confianza, cachear solo
dependencias verificables por hash del lockfile, y no restaurar cachés escritas
por workflows de fork.
</details>

## Permisos y secretos

**6. `GITHUB_TOKEN` vs PAT vs OIDC hacia GCP. ¿Cuál para desplegar?**

<details><summary>Guía</summary>

**OIDC.** `GITHUB_TOKEN` solo sirve dentro de GitHub. Un PAT es una credencial de
larga vida: hay que rotarla, vive en un secreto, y si se filtra vale hasta que
alguien la revoque. OIDC intercambia un token efímero por identidad federada, sin
credencial almacenada en ninguna parte, con confianza acotada a repo y rama
concretos. El coste es la configuración inicial del pool de identidad federada.
</details>

**7. ¿Por qué `permissions` a nivel de workflow y no `write-all`?**

<details><summary>Guía</summary>

Least privilege. `GITHUB_TOKEN` con `write-all` puede empujar código, crear
releases y publicar paquetes; cualquier acción de terceros comprometida en tu
workflow hereda eso. Se declara `permissions: contents: read` a nivel de workflow
y se eleva solo en el job que lo necesite. Y las acciones de terceros se fijan por
SHA, no por tag — un tag de acción también es mutable, exactamente igual que un
tag de imagen.
</details>

## Puertas de despliegue

**8. Tu puerta comprueba que los pods están `READY`. Un release pasa y falla el
19% de las peticiones. ¿Qué faltó?**

<details><summary>Guía</summary>

`READY` refleja la readiness probe, que normalmente solo dice que el proceso
responde en un endpoint. No mide comportamiento en la ruta real. La puerta debe
generar tráfico representativo y medir tasa de error y latencia contra el SLO —
la del módulo 07 — durante una ventana suficiente para que el dato sea
significativo. Y debe poder fallar tanto en falso positivo como en falso
negativo: una puerta que rechaza un release sano cuesta tanta confianza como una
que deja pasar uno roto.
</details>
