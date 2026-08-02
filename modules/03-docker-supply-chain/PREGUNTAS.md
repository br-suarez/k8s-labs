# Preguntas de entrevista — Módulo 03

## Imágenes y capas

**1. Explica el mecanismo del caché de capas. ¿Por qué `COPY go.mod go.sum ./` y
`RUN go mod download` antes de `COPY . .` cambia los tiempos de build?**

<details><summary>Guía</summary>

Cada instrucción produce una capa identificada por un hash de la instrucción más
el contenido que introduce. Si el hash coincide con una capa en caché, se
reutiliza junto con todas las anteriores. Copiar solo los manifiestos de
dependencias primero significa que un cambio en el código fuente no invalida la
capa de descarga de dependencias, que es la cara. La regla general: ordena de
menos a más volátil.
</details>

**2. ¿Puede `app:v1.2.3` apuntar a imágenes distintas en dos máquinas? ¿Qué
implica?**

<details><summary>Guía</summary>

Sí. Un tag es un puntero mutable a un digest: se puede reasignar en cualquier
momento, deliberadamente o no. Si una máquina hizo pull antes del reasignado,
tiene otra imagen. Implicación: los despliegues deben referenciar por digest
(`app@sha256:...`), que es inmutable y verificable. Los tags están bien para
humanos, no para despliegues — y es la base sobre la que el módulo 12 construye
la firma.
</details>

**3. ¿Diferencia entre `ENTRYPOINT ["app"]` y `ENTRYPOINT app`?**

<details><summary>Guía</summary>

La forma exec ejecuta el binario directamente como PID 1. La forma shell lo
envuelve en `/bin/sh -c`, con lo que el shell es PID 1 y **no propaga señales al
hijo**. Resultado: `docker stop` espera el periodo de gracia completo y luego
mata el proceso. Es la causa más común de despliegues lentos y de conexiones
cortadas en cada rollout.
</details>

## Runtime

**4. Un contenedor arranca, corre 10 s y muere. `docker logs` está vacío. Tu
secuencia.**

<details><summary>Guía</summary>

`docker inspect --format '{{.State.ExitCode}} {{.State.OOMKilled}}'` primero:
137 con OOMKilled descarta todo lo demás. Luego `docker events` durante un
reintento. Si el exit code es 0, terminó "bien" y el problema es que el proceso
principal no era el que creías (forma shell, o un wrapper que sale). Logs vacíos
apuntan a que la aplicación escribe a un archivo en vez de a stdout, o murió
antes de inicializar su logger — que es lo que hace un fallo de configuración al
arrancar.
</details>

**5. ¿Qué es exactamente una imagen distroless y qué pierdes al usarla?**

<details><summary>Guía</summary>

Una imagen con solo la aplicación y sus dependencias de runtime: sin shell, sin
gestor de paquetes, sin utilidades. Ganas superficie de ataque mínima y muchos
menos falsos positivos en el escaneo de CVEs. Pierdes la capacidad de `exec`
dentro para depurar, y hereda problemas sutiles: sin `ca-certificates` TLS falla,
sin `tzdata` las zonas horarias fallan, sin `/etc/passwd` algunas librerías que
buscan el usuario fallan. Se depura con contenedores efímeros.
</details>

**6. `CGO_ENABLED=0` — ¿qué hace y por qué importa aquí?**

<details><summary>Guía</summary>

Desactiva cgo, produciendo un binario estático sin dependencia de glibc. Importa
porque permite usar `distroless/static` o `scratch`. Coste: el resolvedor de DNS
pasa a ser el de Go puro en vez del del sistema, lo que cambia el comportamiento
frente a `/etc/nsswitch.conf` y ciertas configuraciones corporativas de DNS — un
fallo desagradable y difícil de encontrar.
</details>

## Cadena de suministro

**7. ¿Por qué escanear en CI no es suficiente?**

<details><summary>Guía</summary>

CI escanea la imagen que construyes, en el momento de construirla. No dice nada
de (a) imágenes desplegadas antes de que el CVE se publicara, (b) imágenes que
llegaron al cluster sin pasar por CI, (c) vulnerabilidades descubiertas después
del build. Hace falta escaneo continuo del registro y control de admisión en el
cluster, que es el módulo 12.
</details>

**8. ¿Qué es un build reproducible y por qué es difícil?**

<details><summary>Guía</summary>

Mismo código fuente → mismo digest, bit a bit. Es difícil porque los builds
capturan timestamps, orden de archivos, rutas absolutas, y versiones de
dependencias resueltas en el momento. Importa porque permite verificar
independientemente que un binario corresponde a un código fuente — sin eso, la
firma solo prueba quién lo construyó, no qué construyó.
</details>

## Trade-offs

**9. Defiende multi-stage + distroless frente a Alpine y frente a una imagen
Debian completa.**

<details><summary>Guía</summary>

Distroless: superficie mínima, sin shell para un atacante, menos CVEs que
triar. Alpine: pequeña y **tiene** shell, lo que la hace mucho más depurable; el
riesgo es musl libc en vez de glibc, que produce diferencias sutiles de
comportamiento (DNS, threads, precisión de tiempo) y ha causado incidentes
reales. Debian completa: máxima depurabilidad y compatibilidad, superficie y
tamaño máximos. La respuesta honesta es que depende de cuánto vale la
depurabilidad en tu operación — un equipo sin `kubectl debug` disponible sufre
mucho con distroless.
</details>
