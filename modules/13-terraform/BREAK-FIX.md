# Break-fix — Módulo 13

## El escenario

Hace tres semanas, el pipeline de infraestructura empezó a fallar de forma
intermitente:

```
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        7a3f9c21-4b8e-4d1a-9f02-c7d1e59f2a4b
  Operation: OperationTypeApply
  Who:       runner@fv-az1234-567
  Created:   2026-07-12 09:14:22.104 +0000 UTC
```

Alguien lo "arregló":

```diff
- terraform apply -auto-approve
+ terraform apply -auto-approve -lock=false
```

Desde entonces el pipeline está verde. Hasta hoy.

## Lo que pasa hoy

```
$ terraform plan
Terraform will perform the following actions:

  # google_compute_instance.worker[0] will be created
  + resource "google_compute_instance" "worker" {
      + name = "pulse-worker-0"
      ...
    }

  # google_storage_bucket.artifacts will be created
  + resource "google_storage_bucket" "artifacts" {
      + name = "pulse-artifacts-prod"
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

Terraform quiere **crear** dos recursos. Pero existen:

```
$ gcloud compute instances list --filter="name=pulse-worker-0"
NAME             ZONE            STATUS
pulse-worker-0   us-central1-a   RUNNING

$ gcloud storage buckets describe gs://pulse-artifacts-prod --format="value(name)"
pulse-artifacts-prod
```

Y si aplicas:

```
Error: googleapi: Error 409: The resource 'projects/.../instances/pulse-worker-0'
already exists, alreadyExists
```

Además, alguien nota esto:

```
$ terraform state list | wc -l
23

$ gcloud compute instances list --filter="labels.managed-by=terraform" --format="value(name)" | wc -l
26
```

Tres instancias existen, están etiquetadas como gestionadas por Terraform, y no
están en el estado.

## Tu trabajo

1. Explica qué hace `-lock=false` y por qué el pipeline dejó de fallar.
2. Reconstruye qué le pasó al fichero de estado durante estas tres semanas.
   ¿Por qué hay recursos que existen y no están en el estado?
3. ¿Por qué el error original —el del bloqueo— **no era un fallo**? ¿Qué te
   estaba diciendo?
4. Tienes tres instancias huérfanas. ¿Qué opciones hay y cuál es el riesgo de
   cada una?
5. **No apliques nada todavía.** ¿Cuál es el primer comando que ejecutas?
6. Recupéralo. Al terminar, `terraform plan` debe decir "No changes" y el estado
   debe reflejar la realidad.
7. Arregla el pipeline para que esto no pueda repetirse. `-lock=false` no era la
   solución, pero el fallo intermitente era real: ¿qué lo causaba de verdad?

## Pistas escalonadas

<details><summary>Pista 1</summary>

El bloqueo existe porque el estado de Terraform es un fichero que se lee entero,
se modifica y se escribe entero. ¿Qué pasa si dos procesos hacen eso a la vez?
</details>

<details><summary>Pista 2 — para el punto 2</summary>

Dos `apply` concurrentes: A lee el estado, B lee el estado, A crea recursos y
escribe el estado, B crea recursos y escribe el estado. ¿Qué contiene el fichero
al final? ¿Y qué pasó con lo que creó A?
</details>

<details><summary>Pista 3 — para el punto 5</summary>

Antes de tocar nada, haz una copia del estado. Es un fichero, y estás a punto de
manipularlo. Los backends remotos suelen tener versionado — compruébalo antes de
necesitarlo.
</details>

<details><summary>Pista 4 — para el punto 7</summary>

El fallo de bloqueo era síntoma de que dos ejecuciones se solapaban. Ya
resolviste ese problema en el módulo 09 para el pipeline de aplicación. ¿Qué
mecanismo usaste allí?
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Porque enseña que **un mensaje de error puede ser un mecanismo de seguridad
funcionando**, y que silenciarlo es la clase de arreglo que parece funcionar
durante semanas. Es el mismo patrón que la excepción de CVE del módulo 09 y el
self-heal desactivado del 10: algo se desactiva "temporalmente" y nadie vuelve.

Y es el requisito previo del módulo 14: sin un estado que refleje la realidad,
`terraform destroy` no destruye lo que crees, y eso cuesta dinero.
