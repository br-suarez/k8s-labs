# Break-fix — Módulo 06

## El escenario

03:40 de la madrugada. Una migración mal aplicada ha borrado la tabla `results`
de Pulse. Sin drama: hay backups nocturnos desde hace seis meses y el CronJob
reporta éxito todas las noches.

Vas a restaurar.

```
$ kubectl get cronjob -n pulse
NAME             SCHEDULE     SUSPEND   ACTIVE   LAST SCHEDULE   AGE
pulse-backup     0 2 * * *    False     0        1h42m           183d

$ kubectl get jobs -n pulse --sort-by=.status.startTime | tail -5
pulse-backup-29344320   Complete   1/1   14s   4d
pulse-backup-29345760   Complete   1/1   11s   3d
pulse-backup-29347200   Complete   1/1   12s   2d
pulse-backup-29348640   Complete   1/1   13s   1d
pulse-backup-29350080   Complete   1/1   12s   1h
```

183 días. Todos `Complete`. Ninguno ha fallado nunca.

## Los archivos

```
$ kubectl exec -n pulse deploy/pulse-api -- ls -la /backups | tail -8
-rw-r--r-- 1 postgres postgres  4823914 Jul 26 02:00 pulse-20260726.sql.gz
-rw-r--r-- 1 postgres postgres  4831022 Jul 27 02:00 pulse-20260727.sql.gz
-rw-r--r-- 1 postgres postgres       20 Jul 28 02:00 pulse-20260728.sql.gz
-rw-r--r-- 1 postgres postgres       20 Jul 29 02:00 pulse-20260729.sql.gz
-rw-r--r-- 1 postgres postgres  1245184 Jul 30 02:00 pulse-20260730.sql.gz
-rw-r--r-- 1 postgres postgres       20 Jul 31 02:00 pulse-20260731.sql.gz
-rw-r--r-- 1 postgres postgres       20 Aug  1 02:00 pulse-20260801.sql.gz
-rw-r--r-- 1 postgres postgres       20 Aug  2 02:00 pulse-20260802.sql.gz
```

Y el de hoy:

```
$ kubectl exec -n pulse deploy/pulse-api -- gunzip -c /backups/pulse-20260802.sql.gz
$ echo $?
0
```

Vacío. Sale bien y no contiene nada.

## El script del CronJob

```bash
#!/bin/sh
set -e

DATE=$(date +%Y%m%d)
pg_dump -h postgres -U pulse -d pulse | gzip > /backups/pulse-$DATE.sql.gz

echo "Backup complete: /backups/pulse-$DATE.sql.gz"
find /backups -name '*.sql.gz' -mtime +30 -delete
```

## El montaje

```yaml
volumes:
  - name: backups
    nfs:
      server: nfs.pulse.svc.cluster.local
      path: /exports/backups
      readOnly: false
```

Montado en los pods con opciones por defecto del cliente NFS del nodo, que en
este cluster incluyen `soft` y `timeo=30`.

## Tu trabajo

1. ¿Por qué el backup de hoy está vacío y el Job reportó éxito? Sé preciso sobre
   el mecanismo.
2. El archivo del 30 de julio pesa 1,2 MB — ni vacío ni completo. Explica ese
   caso, que es distinto del de los de 20 bytes.
3. ¿Qué habría pasado si hubieras restaurado el del 27 de julio, que sí parece
   bueno? ¿Es seguro?
4. Hay **al menos cuatro** defectos entre el script, el montaje y el diseño del
   backup. Encuéntralos.
5. Reescribe el sistema de backup entero. Debe ser imposible que reporte éxito
   sin haber producido un dump restaurable.
6. ¿Qué control operativo, no técnico, faltaba durante seis meses?

## Pistas escalonadas

<details><summary>Pista 1</summary>

20 bytes es exactamente el tamaño de un archivo gzip que comprime cero bytes.
Compruébalo: `printf '' | gzip | wc -c`. Así que `gzip` funcionó perfectamente —
recibió una entrada vacía.
</details>

<details><summary>Pista 2</summary>

`set -e` con una tubería. ¿De qué comando es el código de salida de
`pg_dump | gzip`? Ya viste esto en el módulo 01, en el script de rotación de
logs.
</details>

<details><summary>Pista 3 — para el punto 2</summary>

El archivo de 1,2 MB apunta a otra cosa: una escritura que empezó y se cortó a
mitad. Busca la opción `soft` en el montaje NFS y averigua qué hace cuando el
servidor no responde dentro de `timeo`.
</details>

<details><summary>Pista 4 — para el punto 3</summary>

Aunque el dump esté completo: ¿contiene los roles y permisos de la base, o solo
los datos de una base concreta? ¿Y qué pasa si `pg_dump` corrió mientras había
transacciones abiertas?
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Un backup que nunca se ha restaurado no es un backup, es una hipótesis. Este
escenario es el más caro de todo el track si te pasa de verdad, y es
sorprendentemente común: seis meses de verde en un panel que no medía nada.
