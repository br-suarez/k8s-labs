# Preguntas de entrevista — Módulo 08b

## Fundamentos

**1. ¿Qué es eBPF y por qué se puede cargar código en el kernel sin comprometer
la estabilidad?**

<details><summary>Guía</summary>

Una máquina virtual dentro del kernel que ejecuta programas verificados,
enganchados a puntos concretos: syscalls, tracepoints, kprobes, hooks de red.
La palabra clave es **verificador**: antes de cargar, el kernel demuestra
estáticamente que el programa termina (sin bucles no acotados), que solo accede a
memoria que le pertenece, y que respeta límites de pila e instrucciones. No es
confianza, es prueba. Por eso reemplazó a los módulos de kernel para esta clase
de trabajo.
</details>

**2. ¿Qué es un mapa y por qué hace falta?**

<details><summary>Guía</summary>

Una estructura clave-valor compartida entre el programa en kernel y el espacio de
usuario. Hace falta porque el programa eBPF no puede hacer llamadas arbitrarias
ni escribir donde quiera: acumula resultados en un mapa, y un proceso en espacio
de usuario los lee. Tipos habituales: hash, array, per-CPU (para evitar
contención), y ring buffer para eventos. Elegir per-CPU frente a hash compartido
es la primera decisión de rendimiento que se toma al escribir uno.
</details>

**3. kprobe vs tracepoint. ¿Cuál prefieres y por qué?**

<details><summary>Guía</summary>

Un kprobe se engancha a cualquier símbolo del kernel: máxima cobertura, pero
**se rompe entre versiones** porque los nombres y las firmas internas no son
API estable. Un tracepoint es un punto de instrumentación declarado y estable,
con contrato. Prefieres tracepoint siempre que exista; kprobe cuando no hay otra.
Es la misma tensión que entre una API pública y hurgar en internos.
</details>

## Observabilidad sin instrumentación

**4. No puedes reiniciar ni recompilar un proceso, y necesitas saber qué archivos
abre. Dos formas, y cuál molesta menos.**

<details><summary>Guía</summary>

`lsof -p` o `ls /proc/<pid>/fd` da una **foto** de lo que está abierto ahora, con
coste casi nulo. `strace -e openat -p` da el flujo de aperturas pero **para el
proceso en cada syscall** — puede degradarlo mucho y en producción eso ya ha
causado incidentes. eBPF (`opensnoop`) da el mismo flujo con overhead de un
puñado de nanosegundos por evento, porque el filtrado ocurre en el kernel y no
hay cambio de contexto por syscall. Esa es la razón técnica de existir de eBPF
para observabilidad.
</details>

**5. Tu p99 de aplicación es 40 ms, el cliente mide 4 s, la red está bien. ¿Dónde
está el tiempo?**

<details><summary>Guía</summary>

Antes de `accept()` — cola de accept desbordada, y el cliente esperando un
temporizador de retransmisión TCP; o después de que tu handler termine — el
cliente leyendo lentamente, o buffers de socket. Ambos están fuera del alcance de
cualquier instrumentación en tu código, porque tu proceso todavía no participa o
ya terminó. Se miran con `ss -ltn`, `nstat` y contadores `TcpExt`, o con eBPF
enganchado a `inet_csk_accept`.
</details>

**6. ¿Qué representa el eje horizontal de un flamegraph?**

<details><summary>Guía</summary>

**No es tiempo.** Es la proporción de muestras del perfil en las que esa función
aparecía en la pila, ordenado alfabéticamente para agrupar frames iguales. Ancho
= frecuencia de aparición, no duración ni orden de ejecución. El eje vertical sí
es profundidad de pila. Leerlo como línea temporal es el error más común y lleva
a conclusiones inventadas.
</details>

## Trade-offs

**7. eBPF frente a instrumentación con OpenTelemetry. Argumenta los dos lados.**

<details><summary>Guía</summary>

eBPF: sin cambios de código, sin reinicio, cobertura de todo lo que hay en la
máquina incluidos binarios de terceros, y ve por debajo de la aplicación. Lo que
no puede: **contexto de negocio**. Sabe que hubo una llamada a `write()` de 8 KB;
no sabe que era el checkout del cliente 4471. OTel es lo contrario: semántica
rica que tú defines, a cambio de tocar el código y de cubrir solo lo que
instrumentaste. Un incidente empieza normalmente con métricas y trazas —tienen el
contexto— y baja a eBPF cuando la respuesta no está ahí. La postura equivocada es
creer que tener uno te da observabilidad.
</details>

**8. ¿Qué cuesta eBPF? ¿Es gratis?**

<details><summary>Guía</summary>

No. Cada evento ejecuta código en el kernel: enganchar algo de altísima
frecuencia —`kprobe` sobre cada `sched_switch` en una máquina cargada— tiene
coste medible. El overhead es proporcional a la frecuencia del hook, no a lo
complejo del programa. Se mitiga filtrando **dentro** del kernel en vez de enviar
todo a espacio de usuario, agregando en mapas per-CPU, y muestreando en lugar de
trazar cada evento. La respuesta madura es que hay que medirlo, y el lab 06 lo
mide.
</details>

**9. ¿Qué requisitos tiene eBPF que pueden bloquearlo en un entorno real?**

<details><summary>Guía</summary>

Versión de kernel suficientemente moderna; capacidades del contenedor
(`CAP_BPF`, o `CAP_SYS_ADMIN` en kernels anteriores), lo que choca con una
política que exige contenedores sin privilegios; en cloud gestionado, nodos donde
no controlas el kernel; y CO-RE/BTF disponible si no quieres compilar contra
cada kernel. En serverless o en nodos totalmente gestionados sencillamente no
puedes. Conviene saber esto antes de proponerlo como solución.
</details>
