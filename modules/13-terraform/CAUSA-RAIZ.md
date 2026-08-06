# Causa raíz — Módulo 13

> Solo después de haber escrito tu diagnóstico.

## 1. Qué hace `-lock=false`

Terraform no bloquea recursos: bloquea **el fichero de estado**. El ciclo de un
`apply` es leer el estado entero, planificar, crear o modificar recursos, y
escribir el estado entero.

Sin bloqueo, dos `apply` concurrentes hacen esto:

```
t=0   A lee estado  (23 recursos)
t=1   B lee estado  (23 recursos)     ← misma copia
t=2   A crea worker-0, bucket
t=3   A escribe estado (25 recursos)
t=4   B crea worker-1
t=5   B escribe estado (24 recursos)  ← sobre la copia que leyó en t=1
```

El estado final tiene 24 recursos: los 23 originales más el que creó B. **Todo
lo que creó A desapareció del estado**, aunque existe en la nube.

Es una escritura perdida clásica, exactamente el mismo problema que resolviste
en el módulo 09 con `concurrency` — dos ejecuciones compartiendo un recurso
mutable sin serializar.

El pipeline dejó de fallar porque ya nadie comprobaba si otro estaba escribiendo.
El error desapareció; el problema empeoró.

## 2. Tres semanas de deriva

Cada vez que dos ejecuciones se solaparon, el estado perdió lo que había creado
la que escribió primero. Por eso hay 26 instancias etiquetadas como gestionadas
por Terraform y solo 23 en el estado.

Y por eso `plan` quiere crear `pulse-worker-0`: **para Terraform no existe**. El
estado es su única fuente de verdad sobre lo que gestiona; no consulta la nube
para descubrir recursos, solo refresca los que ya conoce.

De ahí el 409 al aplicar: Terraform pide crear algo que la nube ya tiene.

## 3. El error de bloqueo no era un fallo

Era el mecanismo funcionando. Decía: *"otro proceso está modificando este estado;
espera a que termine"*.

La respuesta correcta a ese mensaje es esperar, o serializar las ejecuciones para
que no coincidan. Nunca desactivarlo.

**Este es el patrón que se repite en todo el track:** un control que molesta se
desactiva "temporalmente" y nadie vuelve. La excepción de CVE del módulo 09, el
`selfHeal=false` del 10, la `PolicyException` del 12, y aquí `-lock=false`. En
los cuatro casos el arreglo es el mismo: quitar la causa del roce, no el control.

## 4. Las tres instancias huérfanas

Tres opciones, con riesgos distintos:

| Opción | Qué hace | Riesgo |
|---|---|---|
| `terraform import` | Las adopta en el estado | Si su configuración no coincide con el código, el siguiente `apply` las modifica o recrea |
| Borrarlas a mano | Elimina el problema | Si alguna está en uso, provocas un incidente |
| Dejarlas y documentar | Aplaza | Siguen costando dinero y nadie las gestiona |

La correcta es **import**, y con cuidado: importar, luego `plan`, y **leer muy
bien** lo que propone antes de aplicar. Un import cuya configuración no coincide
produce un plan que destruye y recrea — que es peor que el problema original.

```bash
terraform import 'google_compute_instance.worker[0]' \
  projects/PROJECT/zones/us-central1-a/instances/pulse-worker-0
terraform plan     # DEBE decir "No changes". Si no, ajusta el código, no el recurso.
```

En Terraform moderno, los bloques `import` en el propio código son mejores: son
declarativos, revisables en un PR, y producen un plan que se puede inspeccionar
antes de ejecutar nada.

## 5. El primer comando

**Copia del estado.** Antes de tocar nada:

```bash
terraform state pull > state-backup-$(date +%Y%m%d-%H%M%S).json

# Y comprueba que el backend tiene versionado, ANTES de necesitarlo
gcloud storage buckets describe gs://tf-state-bucket --format="value(versioning.enabled)"
```

Estás a punto de manipular a mano el fichero que representa toda tu
infraestructura. Es el equivalente a editar la base de datos de producción.

## 6. La recuperación

```bash
# 1. Copia
terraform state pull > backup.json

# 2. Inventario: qué existe en la nube con la etiqueta de gestión
gcloud compute instances list --filter="labels.managed-by=terraform" \
  --format="value(name,zone)" > cloud-inventory.txt

# 3. Qué conoce el estado
terraform state list > state-inventory.txt

# 4. La diferencia son los huérfanos
comm -13 <(sort state-inventory.txt) <(sort cloud-inventory.txt)

# 5. Importar cada uno, verificando el plan después de CADA import
terraform import '<address>' '<id>'
terraform plan          # No changes, o ajusta el código

# 6. Cuando todo esté importado
terraform plan -detailed-exitcode    # exit 0 = estado y realidad coinciden
```

El paso 5 uno a uno, no en lote. Un import que produce un plan destructivo hay
que detectarlo antes de acumular cinco más encima.

## 7. El arreglo del pipeline

El fallo intermitente era real: dos ejecuciones se solapaban. La solución es
serializar, igual que en el módulo 09:

```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false      # nunca cancelar un apply a medias
```

`cancel-in-progress: false` es crítico aquí y por una razón distinta a la del
módulo 09: cancelar un `apply` en vuelo deja el estado sin escribir mientras los
recursos ya existen — creas huérfanos a propósito.

Más protecciones:

```hcl
# El bloqueo, explícitamente activo
terraform {
  backend "gcs" {
    bucket = "tf-state-pulse"
    prefix = "prod"
  }
}
```

```bash
# En CI: nunca -lock=false. Y un timeout en vez de desactivar
terraform apply -auto-approve -lock-timeout=10m
```

`-lock-timeout` es la respuesta correcta al problema original: espera hasta 10
minutos a que se libere el bloqueo en lugar de fallar de inmediato **o** de
ignorarlo.

Y una comprobación en CI que impida que alguien vuelva a poner `-lock=false`:

```bash
grep -rn 'lock=false' .github/ && { echo "FAIL: -lock=false is banned"; exit 1; }
```

Tres líneas que habrían ahorrado tres semanas.

## Cuándo `force-unlock` es legítimo

Solo cuando estás **seguro** de que el proceso que tomó el bloqueo ya no existe:
un runner que murió a mitad, una máquina que se apagó. La información del bloqueo
te dice quién y cuándo — úsala.

```bash
terraform force-unlock 7a3f9c21-4b8e-4d1a-9f02-c7d1e59f2a4b
```

Hacerlo mientras otro `apply` corre de verdad produce exactamente el escenario de
este break-fix, y encima con las dos ejecuciones creyendo que tienen el bloqueo.
