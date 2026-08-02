# Causa raíz — Módulo 06

> Solo después de haber escrito tu lista.

Son **cinco** defectos. El quinto no está en el código.

## Defecto 1 — `set -e` no ve el fallo de `pg_dump`

```bash
pg_dump -h postgres -U pulse -d pulse | gzip > /backups/pulse-$DATE.sql.gz
```

En una tubería, el código de salida es el del **último** comando. `pg_dump` falla
(credenciales caducadas, la base no acepta conexiones, lo que sea), escribe su
error a stderr y sale con 1. `gzip` recibe cero bytes por stdin, comprime cero
bytes correctamente y sale con **0**.

`set -e` mira ese 0 y sigue. El script imprime "Backup complete", borra los
antiguos y termina con éxito. Kubernetes ve `exit 0` y marca el Job `Complete`.

```bash
printf '' | gzip | wc -c
# 20
```

Veinte bytes es la cabecera gzip de un archivo vacío. Ese número es la firma del
fallo.

**Es exactamente el mismo bug del módulo 01**, en otro traje. Si lo reconociste
de inmediato, el repaso espaciado está funcionando.

El arreglo mínimo: `set -o pipefail`. Pero eso solo es el principio.

## Defecto 2 — `soft` en el montaje NFS

El archivo de 1,2 MB del 30 de julio es distinto: ahí `pg_dump` sí funcionó.

Con `soft`, una operación NFS que no obtiene respuesta dentro de `timeo`
**devuelve un error de E/S y continúa** en lugar de reintentar indefinidamente.
Durante una interrupción de red, la escritura se corta a mitad. El archivo queda
truncado.

Y como el error ocurre en `gzip` escribiendo a disco... con `pipefail` sí lo
habrías detectado. Sin él, otra vez silencio.

| Opción | Comportamiento ante fallo del servidor | Cuándo usarla |
|---|---|---|
| `hard` (por defecto) | Reintenta para siempre. El proceso se bloquea en estado `D` | Datos que no pueden corromperse |
| `soft` | Devuelve error de E/S tras `timeo` | Solo lectura, o donde un fallo parcial sea tolerable |
| `hard,intr` | Como `hard` pero interrumpible por señal | Obsoleto en kernels modernos |

Para backups, `hard`. Un proceso colgado es un problema visible; un archivo
truncado silenciosamente es un problema invisible hasta que lo necesitas.

## Defecto 3 — el dump no incluye roles ni permisos

`pg_dump -d pulse` vuelca **una base de datos**: esquema y datos. No incluye los
objetos globales del cluster — roles, permisos, tablespaces.

Al restaurar en una instancia nueva, todos los `GRANT` a roles que no existen
fallan. Puedes acabar con los datos dentro y ninguna aplicación capaz de leerlos.

Hace falta `pg_dumpall --globals-only` por separado, o `pg_dumpall` completo.

## Defecto 4 — no hay verificación ni consistencia declarada

El script nunca comprueba lo que produjo. Tres capas que faltan:

1. **Integridad del archivo:** `gzip -t`.
2. **Que el contenido sea un dump:** que empiece por la cabecera de PostgreSQL y
   termine por el marcador de fin. Un dump truncado pasa `gzip -t` si el corte
   coincide con un bloque.
3. **Que restaure:** lo único que prueba de verdad que sirve.

Sobre el punto 3 de tu lista: `pg_dump` es consistente por sí mismo — usa una
instantánea transaccional, así que el dump del 27 es coherente. Lo que **no**
está garantizado es que sea restaurable, ni que contenga lo que crees.

## Defecto 5 — nadie restauró nunca

El defecto real. Los cuatro anteriores son consecuencias.

Seis meses. 183 ejecuciones. Cero restauraciones. El sistema no medía "¿tenemos
backups?", medía "¿el script terminó?". Son preguntas distintas y solo una
importa a las 03:40.

**La regla:** un backup que nunca se ha restaurado es una hipótesis. Un drill de
restauración periódico y automatizado es lo que la convierte en un hecho — y es
lo que construyes en el lab 03.

## El sistema corregido

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly DATE=$(date +%Y%m%d-%H%M%S)
readonly DEST=/backups
readonly TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

log() { printf '%s %s\n' "$(date -Is)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# 1. Globales aparte: roles y permisos no viajan en pg_dump de una base
pg_dumpall -h postgres -U pulse --globals-only > "$TMP/globals.sql" \
  || die "pg_dumpall failed"

# 2. El dump. Formato custom: comprimido, y restaurable en paralelo y selectivo
pg_dump -h postgres -U pulse -d pulse -Fc -f "$TMP/pulse.dump" \
  || die "pg_dump failed"

# 3. Que no esté vacío
[ -s "$TMP/pulse.dump" ] || die "dump is empty"
size=$(stat -c %s "$TMP/pulse.dump")
[ "$size" -gt 100000 ] || die "dump suspiciously small: ${size} bytes"

# 4. Que sea un dump legible. -l lista el contenido sin restaurar
pg_restore -l "$TMP/pulse.dump" > "$TMP/toc.txt" || die "dump is not readable"
grep -q 'TABLE DATA public results' "$TMP/toc.txt" \
  || die "dump does not contain the results table"

# 5. Escritura atómica: nadie ve nunca un archivo a medias
mv "$TMP/globals.sql" "$DEST/globals-$DATE.sql"
mv "$TMP/pulse.dump"  "$DEST/pulse-$DATE.dump.part"
sync
mv "$DEST/pulse-$DATE.dump.part" "$DEST/pulse-$DATE.dump"

# 6. Purga solo si todo lo anterior fue bien
find "$DEST" -name 'pulse-*.dump' -mtime +30 -delete

log "backup ok: $DEST/pulse-$DATE.dump (${size} bytes)"
```

Cambios que importan:

- `set -euo pipefail`, y sin tuberías donde se pierda el código de salida.
- `-Fc` en vez de `| gzip`: formato custom, comprimido internamente, y
  `pg_restore` puede inspeccionarlo sin descomprimir.
- Verificación en tres capas, incluida una comprobación de que la tabla que te
  importa está dentro.
- `.part` y `mv`: el archivo final aparece completo o no aparece.
- La purga solo se ejecuta si el backup nuevo es válido. En el original,
  **un backup roto borraba los buenos** — el defecto más peligroso de todos.

Y en el montaje: `hard` en vez de `soft`.

## Lo que faltaba, que no es código

```
Un CronJob semanal que:
  1. Levanta un Postgres efímero
  2. Restaura el backup más reciente
  3. Ejecuta una consulta que compruebe un invariante conocido
  4. Falla ruidosamente si algo no cuadra
  5. Publica una métrica: pulse_backup_last_verified_timestamp
```

Esa métrica va al SLO del módulo 07, y una alerta salta si supera las 48 horas.
Así "¿tenemos backups?" se convierte en algo que un panel puede responder de
verdad.
