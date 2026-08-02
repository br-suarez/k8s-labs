# Preguntas de entrevista — Módulo 01

## Bash y manejo de errores

**1. ¿Por qué `set -e` no es suficiente? Nombra dos casos donde no hace nada.**

<details><summary>Guía</summary>

No aborta cuando el comando está en una sustitución `$( )`, en una condición
(`if`, `&&`, `||`, `!`), o cuando falla un comando intermedio de una tubería sin
`pipefail`. Tampoco dentro de funciones invocadas en un contexto condicional.
`set -euo pipefail` cubre más, pero la respuesta senior es que el manejo de
errores explícito no se sustituye con flags.
</details>

**2. `set -u` rompe un script que llevaba años funcionando. ¿Cómo lo introduces
en un script heredado sin romper producción el lunes?**

<details><summary>Guía</summary>

`${VAR:-default}` para las opcionales, `${VAR:?mensaje}` para las obligatorias.
Se despliega primero en modo observación (loguear qué variables estarían sin
definir), y solo después se activa. La respuesta que se busca es que sabes que
un cambio "obviamente correcto" en un script de producción necesita una fase de
observación.
</details>

**3. `df` dice 98% lleno, `du -sh` sobre el mismo punto de montaje dice 40%.
¿Qué está pasando y cómo lo confirmas?**

<details><summary>Guía</summary>

Archivos borrados con descriptores aún abiertos: el inodo persiste hasta que el
último `fd` se cierra, `du` no los ve pero el sistema de archivos sí.
`lsof +L1` los lista. Se resuelve reiniciando o señalando al proceso que los
tiene abiertos — no con `rm`, que ya se hizo. Segunda causa posible: agotamiento
de inodos (`df -i`), donde el espacio existe pero no hay dónde registrar
archivos nuevos.
</details>

## Diagnóstico de procesos

**4. Un proceso está al 100% de CPU y no escribe logs. Describe tu secuencia.**

<details><summary>Guía</summary>

`top -H -p <pid>` para ver si es un hilo o todos. `cat /proc/<pid>/wchan` y
`/proc/<pid>/stack` para ver si está bloqueado en el kernel. `strace -c -p <pid>`
para contar syscalls: mucha llamada = I/O o contención; **ninguna llamada = CPU
pura en espacio de usuario**, y ahí strace no te sirve, necesitas `perf top -p`
o un profiler. `lsof -p` para archivos y sockets. Lo que se evalúa es que sepas
cuándo *dejar* de usar strace.
</details>

**5. ¿Cuál es la diferencia entre `MemFree` y `MemAvailable` en `/proc/meminfo`,
y cuál usarías para decidir si puedes arrancar un pod?**

<details><summary>Guía</summary>

`MemFree` es memoria sin tocar. `MemAvailable` estima lo que se puede obtener sin
swapear, incluyendo page cache reclamable. Casi siempre quieres `MemAvailable`:
un sistema sano tiene `MemFree` bajo porque el kernel usa la RAM libre como
caché, y alarmarse por eso es un clásico.
</details>

**6. Explica qué significa exactamente el load average `4.00` en una máquina de
4 CPUs. ¿Es un problema?**

<details><summary>Guía</summary>

En Linux el load average cuenta procesos ejecutables **y** en espera
ininterrumpible de disco (estado D) — no es solo CPU. 4.00 en 4 CPUs puede ser
utilización perfecta o puede ser un proceso al 100% y tres bloqueados en un NFS
colgado. Sin mirar la descomposición (`vmstat 1`, columnas `r` y `b`) el número
solo no dice nada. Esta distinción, y que Linux difiere aquí de otros Unix, es
lo que separa la respuesta de manual de la respuesta con experiencia.
</details>

## Señales

**7. ¿Diferencia entre `SIGTERM`, `SIGKILL` y `SIGHUP` para un servicio? ¿Por qué
Kubernetes manda `SIGTERM` y no `SIGKILL`?**

<details><summary>Guía</summary>

`SIGTERM` es capturable: el proceso puede drenar conexiones y cerrar limpio.
`SIGKILL` no es capturable ni ignorable, lo ejecuta el kernel — sin oportunidad
de limpiar. `SIGHUP` históricamente "colgó la terminal", hoy es por convención
"recarga tu configuración". Kubernetes manda `SIGTERM`, espera
`terminationGracePeriodSeconds` (30 por defecto) y solo entonces `SIGKILL`. Si tu
proceso no captura `SIGTERM`, cada despliegue corta peticiones en vuelo.
</details>

**8. Tu contenedor ignora `SIGTERM` y tarda 30 s en morir en cada despliegue.
Nombra dos causas probables.**

<details><summary>Guía</summary>

(a) El proceso corre como PID 1 y no tiene manejador: PID 1 no recibe las
acciones por defecto de las señales, así que un `SIGTERM` sin `trap` no hace
nada. (b) El `ENTRYPOINT` es un shell (`sh -c "app"`) que no propaga la señal al
hijo. Se resuelve con la forma exec del entrypoint, o con un init como `tini`.
Es exactamente el fallo que módulo 03 provoca a propósito.
</details>
