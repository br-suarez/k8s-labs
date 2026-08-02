# Break-fix — Módulo 01

## El escenario

Un cron nocturno rota y comprime los logs de Pulse. Lleva ocho meses en
producción sin tocarse. Este es el script:

```bash
#!/bin/bash
set -e

LOG_DIR=/var/log/pulse
ARCHIVE_DIR=/var/log/pulse/archive
RETENTION_DAYS=30

mkdir -p $ARCHIVE_DIR

# Compress yesterday's logs
for f in $(ls $LOG_DIR/*.log); do
  gzip -c $f > $ARCHIVE_DIR/$(basename $f).$(date +%Y%m%d).gz
  cat /dev/null > $f
done

# Purge old archives
find $ARCHIVE_DIR -name "*.gz" -mtime +$RETENTION_DAYS -delete

echo "Rotation complete: $(ls $ARCHIVE_DIR | wc -l) archives"
```

Esta mañana, la guardia reporta tres cosas a la vez:

1. El disco de `/var/log` está al **98%**, aunque el cron dice que terminó bien.
2. Faltan los logs de anoche entre las 02:00 y las 04:00, justo la ventana donde
   hubo un incidente que hay que investigar.
3. El cron reportó `exit 0`. Los últimos siete días también.

Además, en el directorio hay un archivo llamado literalmente:

```
/var/log/pulse/pulse-api 2026-07-30.log
```

## Tu trabajo

1. Encuentra **todos** los bugs. Hay más de uno y son independientes: al menos
   cuatro defectos reales, no variaciones del mismo.
2. Para cada uno: qué síntoma de los tres provoca, y por qué `set -e` no lo
   detuvo.
3. Reescribe el script correctamente. Debe pasar `shellcheck` sin avisos.
4. Escribe la prueba que habría detectado esto antes de producción.

## Pistas escalonadas

<details><summary>Pista 1</summary>

Empieza por el nombre de archivo con espacio. Recorre el script y pregúntate qué
hace cada línea con ese archivo concreto.
</details>

<details><summary>Pista 2</summary>

`set -e` tiene excepciones documentadas. Una de ellas explica por qué el cron
sale con 0 aunque algo falle dentro del bucle. ¿Qué pasa con el código de salida
de un comando dentro de una sustitución `$( )`? ¿Y con el del último comando de
una tubería?
</details>

<details><summary>Pista 3</summary>

Sobre el disco lleno: `gzip -c $f > destino` seguido de `cat /dev/null > $f`.
¿Qué pasa si el proceso que escribe en `$f` mantiene el descriptor abierto? Y por
separado: ¿qué pasa si el script se ejecuta dos veces el mismo día?
</details>

<details><summary>Pista 4</summary>

`find -mtime +30` sobre `$ARCHIVE_DIR`. ¿Qué `mtime` tienen los archivos que
acabas de crear con `gzip -c > destino`? ¿Y de dónde sale esa fecha — del
contenido original o del momento de creación?
</details>

Causa raíz en `CAUSA-RAIZ.md`. Escribe tu lista de bugs antes de abrirlo, y
compara: lo interesante no es cuántos encontraste, sino cuáles no.
