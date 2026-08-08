# Preguntas de entrevista — Módulo 15

## Ansible

**1. `changed=0` en la segunda ejecución. ¿Demuestra idempotencia?**

<details><summary>Guía</summary>

No. Demuestra que Ansible **cree** que no cambió nada. Un `command` con
`changed_when: false` reporta `ok` haga lo que haga. Una tarea con un `when` que
nunca se cumple reporta `skipped` y parece limpia. Y un módulo puede no detectar
una diferencia que existe. `changed=0` es necesario, no suficiente: la prueba real
es `--check --diff` más verificar el estado final de forma independiente.
</details>

**2. Una tarea `shell` siempre reporta `changed`. ¿Cómo lo arreglas y cuál es el
riesgo?**

<details><summary>Guía</summary>

`changed_when` con una condición sobre la salida, o `creates`/`removes` para que
no se ejecute si ya está hecho. El riesgo de `changed_when: false` puesto por
comodidad es que oculta cambios reales: la tarea modifica el sistema en cada
ejecución y el recap dice que no. La solución de verdad casi siempre es usar el
módulo específico en vez de `shell` — hay uno para casi todo, y son idempotentes
por diseño.
</details>

**3. Handlers: ¿cuándo se ejecutan y cuál es la trampa?**

<details><summary>Guía</summary>

Al final del play, una sola vez por handler, y solo si alguna tarea lo notificó.
La trampa: si el play falla antes de llegar al final, **los handlers no se
ejecutan** — puedes acabar con la configuración escrita y el servicio sin
reiniciar, que es el peor estado posible. `force_handlers: true` o `meta:
flush_handlers` en un punto controlado lo mitigan.
</details>

## Ansible sobre Kubernetes

**4. Un playbook parchea nodos del cluster. ¿Qué debe hacer antes de tocar cada
uno?**

<details><summary>Guía</summary>

`serial: 1` para no tocar varios a la vez; cordonar; drenar **respetando los
PDBs** —sin `--disable-eviction`—; esperar convergencia después del reinicio con
`kubectl wait`, no solo a que el host responda; y verificar la salud del servicio
antes de pasar al siguiente, con reintentos. La verificación de salud es la parte
que la mayoría omite, y es la que distingue ejecutar comandos de operar un
sistema.
</details>

**5. `--disable-eviction` y `--force` en `kubectl drain`. ¿Qué te saltas con cada
uno?**

<details><summary>Guía</summary>

`--disable-eviction` borra los pods directamente en vez de usar la Eviction API,
así que **los PodDisruptionBudgets no se consultan**. `--force` borra pods sin
controlador, que no volverán porque nada los recrea. Ambos existen para
desatascar un drenaje concreto; ponerlos por defecto en un playbook periódico es
desactivar permanentemente los mecanismos de seguridad que configuraste aparte.
</details>

**6. Tu playbook termina con `failed=0` y el servicio estuvo caído. ¿Cómo es
posible?**

<details><summary>Guía</summary>

Ansible reporta el resultado de sus tareas, y todas devolvieron 0. Ninguna
preguntó por la salud del servicio. Es el choque de modelos: Ansible es
imperativo y síncrono, Kubernetes declarativo y asíncrono — un comando aceptado
no significa un sistema convergido. El arreglo es incorporar verificación de
estado al propio playbook, con reintentos, no confiar en los códigos de salida.
</details>

## Jenkins

**7. Heredas un Jenkinsfile de 400 líneas. ¿Las tres primeras cosas que miras?**

<details><summary>Guía</summary>

(1) Las credenciales: qué secretos usa, cómo se inyectan, y si se imprimen en los
logs — `set -x` en un `sh` con una credencial en el entorno es una filtración.
(2) Los agentes: dónde se ejecuta, si hay estado en el nodo, si depende de
herramientas instaladas a mano — la fuente número uno de "solo funciona en el
agente viejo". (3) Los disparadores y las condiciones de rama: qué lo lanza y qué
despliega a producción.
</details>

**8. ¿Qué transfiere de un Jenkinsfile declarativo a GitHub Actions y qué no?**

<details><summary>Guía</summary>

Transfiere casi uno a uno: stages→jobs, steps→steps, agent→runs-on,
environment→env, credentials→secrets, post→if conditions. No transfiere: los
plugins —el ecosistema de Jenkins es su mayor activo y su mayor atadura—, el
estado en los agentes, las bibliotecas compartidas de Groovy, y cualquier cosa
que dependa del sistema de ficheros del controlador. La migración real es
inventariar plugins, no traducir sintaxis.
</details>

**9. ¿Cuándo NO migrarías de Jenkins?**

<details><summary>Guía</summary>

Cuando depende de plugins sin equivalente —integraciones con hardware,
herramientas de dominio, sistemas internos—; cuando los builds necesitan agentes
con requisitos especiales que tu alternativa no soporta; cuando el equipo tiene
mucha experiencia operándolo y ninguna con lo nuevo; o cuando el coste de
migración supera al de mantenerlo y no hay presión de seguridad. "Es antiguo" no
es un motivo. Saber defender el *no* es lo que hace creíble el *sí*.
</details>

**10. ¿Qué hace Ansible mejor que un operador de Kubernetes, y al revés?**

<details><summary>Guía</summary>

Ansible: todo lo que no es un contenedor —VMs, appliances de red, bare metal,
arranque inicial de máquinas—, ejecución puntual y bajo control humano, y sin
necesidad de agente. Un operador: reconciliación continua, reacción a eventos, y
gestión del estado deseado dentro del cluster. La línea: Ansible empuja un cambio
cuando tú lo lanzas; un operador mantiene un estado indefinidamente. Confundirlos
lleva a playbooks que reinventan un bucle de reconciliación con cron.
</details>
