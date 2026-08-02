# Preguntas de entrevista — Módulo 00

Respóndelas en voz alta, cronometradas, sin notas. Si tardas más de 2 minutos en
una, va directa al repaso de 30 días.

## Entorno y contenedores

**1. kind ejecuta nodos de Kubernetes como contenedores Docker. ¿Qué implica eso
para el aislamiento frente a nodos en VMs, y qué clase de fallo de producción
*no* vas a poder reproducir en kind?**

<details><summary>Guía</summary>

Los nodos comparten el kernel del host. No puedes reproducir: fallos de driver o
de módulo de kernel por nodo, particiones de red reales entre hosts, presión de
memoria a nivel de nodo independiente por nodo (todo compite por la misma RAM),
ni comportamiento del kubelet frente a fallos de disco físico. Sí reproduces
todo lo que vive por encima del kernel: scheduling, control plane, CNI, RBAC,
almacenamiento vía CSI de prueba.
</details>

**2. Un contenedor sale con código 137. ¿Qué sabes de inmediato y cuáles son las
dos causas más probables?**

<details><summary>Guía</summary>

137 = 128 + 9 → `SIGKILL`. Causas: OOM killer del kernel (memoria del host o
límite del cgroup del contenedor) o un `docker kill` explícito. Se distinguen con
`docker inspect --format '{{.State.OOMKilled}}'`. Un 137 con `OOMKilled: false`
apunta a algo externo que lo mató, no a memoria.
</details>

**3. ¿Por qué instalar Docker Engine dentro de WSL en vez de usar Docker Desktop?
Da también un argumento a favor de Docker Desktop.**

<details><summary>Guía</summary>

A favor de Engine en WSL: una VM menos, menos memoria, acceso directo a
`dockerd` y a sus logs, sin capa de proxy que oculte comportamiento. A favor de
Desktop: gestión de credenciales integrada, Kubernetes de un clic, y en equipos
mixtos Windows/macOS es un entorno idéntico para todos — que en soporte interno
vale mucho.
</details>

## Trade-offs

**4. Defiende kind frente a k3d para un entorno de aprendizaje de SRE. Ahora
defiende lo contrario para un pipeline de CI.**

<details><summary>Guía</summary>

Aprendizaje: kind usa kubeadm y etcd reales; k3s sustituye componentes (SQLite en
vez de etcd, Traefik embebido, binario unificado) y con ello oculta modos de
fallo que hay que saber reconocer. CI: k3d arranca en ~20s frente a ~45s, y ese
delta multiplicado por cada job domina el coste. En CI no estás aprendiendo a
depurar etcd: estás verificando que tu chart aplica.
</details>

**5. ¿Por qué este repo fija versiones exactas en vez de usar `latest`? ¿Cuál es
el coste de fijarlas?**

<details><summary>Guía</summary>

A favor: reproducibilidad. Un lab que pasa hoy y falla en tres semanas no enseña
nada, y el pin separa "mi cambio lo rompió" de "el mundo cambió". El coste es la
deriva: el pin envejece, acumulas CVEs sin parchear y llega el día del salto
grande. La respuesta madura es fijar **y** renovar automáticamente
(Renovate/Dependabot), no fijar y olvidar.
</details>

**6. `autoMemoryReclaim=gradual` en `.wslconfig` — ¿qué problema resuelve y qué
coste tiene?**

<details><summary>Guía</summary>

Sin él, WSL2 retiene la memoria que llegó a usar aunque los procesos hayan
terminado, y Windows la ve ocupada indefinidamente. `gradual` la devuelve poco a
poco. El coste: si el workload vuelve a crecer, hay que re-reclamarla, lo que
introduce latencia. `dropcache` es más agresivo y peor para cargas que oscilan.
</details>

## Escalado del criterio de salida

**7. Diseña la comprobación de arranque que le darías a una persona en su primer
día para que su entorno no falle en la semana 3. Debe devolver un código de
salida, no un documento.**

<details><summary>Qué se está evaluando</summary>

Que verifiques *capacidades*, no presencia de binarios: no "¿está docker
instalado?" sino "¿puede este usuario ejecutar un contenedor sin sudo?". No
"¿está kind?" sino "¿puede crear y destruir un cluster?". Y que compruebes los
recursos (memoria, disco) contra el mínimo real, porque ese es el fallo que
aparece tarde y en el peor momento.
</details>
