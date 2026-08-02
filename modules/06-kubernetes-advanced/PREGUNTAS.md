# Preguntas de entrevista — Módulo 06

## Estado y StatefulSets

**1. ¿Qué te da un StatefulSet que un Deployment con un PVC no?**

<details><summary>Guía</summary>

Identidad de red estable (`pod-0`, `pod-1`, con DNS por pod vía Service
headless), un PVC propio y persistente por réplica mediante
`volumeClaimTemplates`, y garantías de orden en creación, actualización y
borrado. Un Deployment con un PVC comparte ese PVC entre réplicas — que con
`ReadWriteOnce` significa que solo una réplica puede arrancar, y ese es el
síntoma de "mi segunda réplica se queda en Pending para siempre".
</details>

**2. `ReadWriteOnce` vs `ReadWriteOncePod` vs `ReadWriteMany`. Un caso donde
confundir los dos primeros corrompe datos.**

<details><summary>Guía</summary>

`ReadWriteOnce` es por **nodo**, no por pod: dos pods en el mismo nodo pueden
montar el mismo volumen a la vez. Si son dos réplicas de una base de datos que
asume acceso exclusivo, ambas escriben en los mismos archivos y corrompen el
almacén. `ReadWriteOncePod` (estable desde 1.29) garantiza un único pod y es lo
que quieres para bases de datos. Que `RWO` sea por nodo sorprende a mucha gente y
es exactamente donde se cuela el bug.
</details>

**3. Un pod lleva 20 minutos en `Terminating`. Cuatro causas.**

<details><summary>Guía</summary>

(a) Un finalizer que nadie resuelve — `kubectl get pod -o jsonpath` sobre
`metadata.finalizers`. (b) El proceso ignora `SIGTERM` y el grace period es muy
largo. (c) Un volumen que no se desmonta, típicamente NFS con el servidor caído:
el proceso está en estado `D` y ni el kernel puede matarlo. (d) El kubelet del
nodo no responde, así que nadie ejecuta el borrado. Se distinguen con
`describe`, `kubectl get node`, y mirando el estado del proceso en el nodo.
</details>

## NFS y almacenamiento en red

**4. El servidor NFS deja de responder. ¿Qué les pasa a los procesos que estaban
leyendo, y por qué `kubectl delete pod --force` es peligroso?**

<details><summary>Guía</summary>

Con `hard` (por defecto) los procesos entran en estado `D` — espera
ininterrumpible — y no son matables ni con `SIGKILL`; el load average se dispara
aunque no haya CPU en uso. `--force` borra el objeto del API server **sin esperar
a que el kubelet confirme la limpieza**: el pod desaparece de `kubectl` mientras
el proceso puede seguir vivo en el nodo con el volumen montado. Con un volumen
`ReadWriteMany` eso permite que el reemplazo escriba a la vez que el zombi —
corrupción. `--force` sobre almacenamiento en red es de las cosas más peligrosas
que ofrece `kubectl`.
</details>

**5. `hard` vs `soft` en NFS. ¿Cuál eliges para backups y por qué?**

<details><summary>Guía</summary>

`hard`. Con `soft`, una interrupción devuelve un error de E/S y el proceso
continúa, produciendo archivos truncados silenciosamente. Prefieres un proceso
bloqueado y visible a un archivo corrupto e invisible. `soft` tiene sentido para
montajes de solo lectura donde un fallo parcial es aceptable y colgar un proceso
no lo es.
</details>

## Disponibilidad

**6. PodDisruptionBudget: ¿qué protege y qué no?**

<details><summary>Guía</summary>

Protege frente a interrupciones **voluntarias**: `kubectl drain`, actualización
de nodos, el cluster autoscaler. No protege de nada involuntario — un nodo que
se muere, un OOMKill, un fallo de hardware. Trampa clásica: un PDB con
`minAvailable` igual al número de réplicas bloquea el drain para siempre y
paraliza el mantenimiento del cluster. Y con una sola réplica, cualquier PDB
significativo hace lo mismo.
</details>

**7. Cluster HA con tres nodos de control plane. Pierdes uno: sigue funcionando.
Pierdes dos: se para. ¿Por qué exactamente?**

<details><summary>Guía</summary>

etcd usa Raft y necesita quórum, que es la mayoría: con 3 miembros el quórum es
2. Con uno caído quedan 2, hay mayoría y se admiten escrituras. Con dos caídos
queda 1, no hay mayoría, y etcd pasa a solo lectura para no arriesgar split
brain. Corolario que se pregunta a menudo: un cluster de 2 miembros es **peor**
que uno de 1, porque el quórum sigue siendo 2 y cualquier fallo lo tumba. Por eso
los números impares.
</details>

## Backups

**8. ¿Qué comprobarías antes de confiar en un backup que lleva seis meses
reportando éxito?**

<details><summary>Guía</summary>

Restaurarlo. Es la única respuesta completa. Después: que el tamaño sea coherente
con el crecimiento de los datos, que el contenido incluya lo que crees (roles y
permisos, no solo tablas), que la retención funcione, que el backup no viva en el
mismo dominio de fallo que el original, y que exista una métrica de "última
restauración verificada con éxito" con alerta. Un panel verde que solo mide "el
script terminó" no mide nada.
</details>

**9. Define RPO y RTO para Pulse y justifica los números.**

<details><summary>Guía</summary>

RPO = cuántos datos aceptas perder; con backup nocturno son hasta 24 h, y se
reduce con WAL archiving o replicación. RTO = cuánto tardas en volver; depende
del tamaño del dump y de si el procedimiento está automatizado o es un humano
leyendo un runbook a las 4am. Lo que se evalúa es que los derives del impacto de
negocio y no al revés: para Pulse, perder 24 h de *resultados de sondeo* es
tolerable, perder 24 h de *definiciones de checks* probablemente no — y eso
sugiere tratar las dos tablas de forma distinta.
</details>
