# Causa raíz — Módulo 01

> Solo después de haber escrito tu lista de bugs.

Son **seis** defectos. Si encontraste cuatro, vas bien; el 5 y el 6 son los que
casi nadie ve.

## Bug 1 — `for f in $(ls ...)`: word splitting

`ls` devuelve una cadena que el shell parte por espacios. El archivo
`pulse-api 2026-07-30.log` se convierte en dos "archivos": `pulse-api` y
`2026-07-30.log`. Ninguno existe.

**Síntoma que causa:** los logs de ese archivo nunca se archivan → contribuye al
disco lleno.

**Correcto:**
```bash
for f in "$LOG_DIR"/*.log; do
  [ -e "$f" ] || continue   # el glob sin coincidencias se expande a sí mismo
```

## Bug 2 — variables sin comillas en todas partes

`$LOG_DIR`, `$f`, `$ARCHIVE_DIR` sin comillar. Mismo problema con cualquier ruta
que contenga espacios, y el motivo por el que `shellcheck` grita (SC2086).

## Bug 3 — `set -e` no aplica dentro de `$( )` ni en el bucle

Este es el que explica el `exit 0` mentiroso. `set -e` **no** aborta cuando:

- El comando forma parte de una sustitución de comandos: `$(ls $LOG_DIR/*.log)`
  falla y el script sigue.
- El fallo ocurre en cualquier comando de una tubería que no sea el último (sin
  `set -o pipefail`).
- El comando está en una condición (`if`, `&&`, `||`).

**Síntoma:** el cron reporta éxito siete días seguidos mientras no archiva nada.

**Correcto:** `set -euo pipefail` y comprobación explícita de los comandos que
importan. `set -e` es una red de seguridad, no una estrategia de errores.

## Bug 4 — pérdida de datos entre `gzip` y `cat /dev/null`

```bash
gzip -c $f > destino    # lee el archivo
cat /dev/null > $f      # lo trunca
```

Entre las dos líneas pasa tiempo. Todo lo que la aplicación escriba en esa
ventana se pierde al truncar. **Esa es la causa de los logs desaparecidos entre
las 02:00 y las 04:00**: no se borraron, se escribieron y se truncaron.

**Correcto:** `logrotate` con `copytruncate`, o mejor, rotación por señal —
la aplicación cierra y reabre su archivo cuando recibe `SIGHUP`. Un script no
debería estar haciendo esto en 2026.

## Bug 5 — el descriptor de archivo abierto

Aunque truncar fuese seguro, `cat /dev/null > $f` no libera espacio si otro
proceso mantiene el descriptor abierto. El inodo sigue vivo y el espacio sigue
ocupado hasta que ese proceso cierre el archivo o muera.

**Síntoma:** `du` dice que `/var/log` está casi vacío y `df` dice 98%. Es la
discrepancia clásica.

**Cómo confirmarlo:**
```bash
lsof +L1                       # archivos borrados aún abiertos
lsof -p <pid> | grep deleted
```

## Bug 6 — `find -mtime` sobre archivos con fecha equivocada

`gzip -c $f > $ARCHIVE_DIR/...gz` crea el archivo **ahora**, así que su `mtime`
es la fecha de archivado, no la del contenido. Como el script se ejecuta a
diario, ningún archivo llega nunca a tener `mtime +30`... salvo que el cron falle
unos días.

Y al revés: el nombre lleva `$(date +%Y%m%d)` — la fecha de *hoy*, no la del log
que contiene. Con lo cual el archivo llamado `20260730` puede contener logs del
29 si el cron se retrasó.

**Síntoma:** la purga no purga → disco lleno. Y la investigación del incidente
busca en el archivo equivocado.

## La versión corregida

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly LOG_DIR=${LOG_DIR:-/var/log/pulse}
readonly ARCHIVE_DIR="$LOG_DIR/archive"
readonly RETENTION_DAYS=${RETENTION_DAYS:-30}

log() { printf '%s %s\n' "$(date -Is)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

[ -d "$LOG_DIR" ] || die "log directory not found: $LOG_DIR"
mkdir -p "$ARCHIVE_DIR" || die "cannot create $ARCHIVE_DIR"

archived=0
shopt -s nullglob
for f in "$LOG_DIR"/*.log; do
  stamp=$(date -r "$f" +%Y%m%d-%H%M%S)
  dest="$ARCHIVE_DIR/$(basename "$f" .log).$stamp.gz"

  [ -e "$dest" ] && { log "already archived, skipping: $dest"; continue; }

  if ! gzip -c "$f" > "$dest.tmp"; then
    rm -f "$dest.tmp"
    die "compression failed for $f"
  fi
  gzip -t "$dest.tmp" || die "archive failed integrity check: $dest"
  mv "$dest.tmp" "$dest"
  archived=$((archived + 1))
done

# Signal the app to reopen its logs instead of truncating underneath it.
if [ -f /run/pulse-api.pid ]; then
  kill -HUP "$(cat /run/pulse-api.pid)" || log "WARN: could not signal pulse-api"
fi

find "$ARCHIVE_DIR" -name '*.gz' -mtime "+$RETENTION_DAYS" -print -delete

log "rotation complete: $archived archived"
```

Puntos clave: `nullglob` en vez de `ls`, escritura a `.tmp` y `mv` atómico,
verificación de integridad antes de dar por bueno el archivo, `mtime` del archivo
original para el nombre, y `SIGHUP` en vez de truncar.

## La prueba que lo habría detectado

```bash
# Crea el caso patológico en un directorio temporal
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/archive"
printf 'line\n' > "$tmp/pulse-api 2026-07-30.log"   # con espacio
printf 'line\n' > "$tmp/pulse-worker.log"

LOG_DIR="$tmp" ./rotate.sh
[ "$(find "$tmp/archive" -name '*.gz' | wc -l)" -eq 2 ] \
  || { echo "FAIL: expected 2 archives"; exit 1; }
```

Un archivo con espacio en el nombre en la suite de pruebas habría matado los bugs
1 y 2 el primer día. **La lección no es "comilla tus variables": es que los casos
límite hay que meterlos en las pruebas, porque producción los va a generar
solo.**
