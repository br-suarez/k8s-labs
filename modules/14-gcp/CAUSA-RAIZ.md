# Causa raíz — Módulo 14

> Solo después de haber escrito tu diagnóstico.

## 1 y 2. Quién creó esos recursos

**Los discos** los creó el *GCE PD CSI driver* dentro del cluster, cuando
vinculaste los `PersistentVolumeClaim` de Postgres y del volumen de artefactos
del módulo 06. El nombre lo delata: `gke-<cluster>-pvc-<uid-del-pvc>`.

**La regla de reenvío y la IP** las creó el *cloud controller manager* de GKE
cuando aplicaste un `Service` de tipo `LoadBalancer`.

Los dos son componentes que corren **dentro** del cluster y tienen credenciales
para crear recursos en tu proyecto de GCP. Es el diseño esperado: así funciona la
integración de Kubernetes con la nube.

## 3. Por qué `destroy` no se los llevó

Terraform destruye lo que hay en su estado. Su estado contiene el cluster GKE,
la VPC, la cuenta de servicio — lo que **él** creó.

Los discos y el balanceador los creó otro actor. Terraform no sabe que existen,
así que no los destruye. Y al eliminar el cluster, **elimina también al único
componente que sabía que existían y podría haberlos limpiado**.

Ese es el punto: destruir el cluster no limpia lo que el cluster creó; lo
convierte en huérfano. El propietario desaparece y los recursos se quedan.

## 4. Por qué no estaban en el estado

Porque el estado de Terraform no es un inventario de tu proyecto de GCP: es un
registro de lo que Terraform gestiona. No escanea la nube; no descubre recursos.

Es exactamente el mismo límite del break-fix del módulo 13, desde otro ángulo.
Allí el estado perdió recursos que Terraform sí había creado; aquí nunca supo de
unos que creó otro. En los dos casos la lección es la misma: **el estado no es la
realidad, es lo que Terraform cree.**

Y el paralelo con el módulo 12 es exacto: la política de admisión controla lo que
entra, no lo que hay. El estado de Terraform controla lo que él creó, no lo que
existe. Los dos necesitan un control de estado aparte.

## 5. Las dos razones de las alertas mudas

### a) Sin canal de notificación

```yaml
notificationsRule:
  monitoringNotificationChannels: []
```

El presupuesto existe, los umbrales existen, y **no hay a quién avisar**. Crear
un presupuesto no crea el canal: hay que crear un `NotificationChannel` en Cloud
Monitoring, verificarlo —GCP manda un correo de confirmación que hay que
pulsar— y referenciarlo.

Un canal sin verificar no recibe nada, y esa es la mitad silenciosa del fallo.

### b) El retraso de la facturación

Aunque el canal funcionara, los datos de facturación de GCP se consolidan con
retraso: típicamente varias horas, y hasta 24 en algunos SKU. Los presupuestos
se evalúan sobre datos consolidados.

Consecuencia: **un presupuesto no es un límite de gasto, es una alarma con
retraso.** No puede impedir nada; te avisa cuando ya gastaste. Con recursos que
se cobran por hora, eso puede ser un día entero de coste antes del primer aviso.

Si necesitas un tope duro, hace falta una función que reaccione al evento del
presupuesto y desactive la facturación del proyecto — que es agresivo y hay que
saber lo que hace.

## 6. Limpiar y verificar

```bash
# Discos huérfanos: creados por GKE, sin usuario
gcloud compute disks list --filter="-users:*" --format="table(name,zone,sizeGb,status)"
gcloud compute disks delete NOMBRE --zone=ZONA --quiet

# Reglas de reenvío y balanceadores
gcloud compute forwarding-rules list
gcloud compute target-pools list
gcloud compute forwarding-rules delete NOMBRE --region=REGION --quiet

# IPs reservadas sin usar
gcloud compute addresses list --filter="status!=IN_USE"
gcloud compute addresses delete NOMBRE --region=REGION --quiet

# Y lo que casi nadie mira
gcloud compute snapshots list
gcloud compute images list --no-standard-images
gcloud container images list
gcloud storage buckets list
```

La comprobación general, que es la que va al harness:

```bash
# ¿Queda algo facturable en el proyecto?
gcloud asset search-all-resources --scope="projects/$PROJECT" \
  --format="table(assetType,displayName)" \
  | grep -vE 'ServiceAccount|Project|Budget'
```

`gcloud asset search-all-resources` es el comando que responde la pregunta
"¿qué hay realmente en mi proyecto?" sin depender de recordar cada tipo de
recurso. Es el que hay que memorizar.

## 7. El arreglo, dos enfoques complementarios

### a) Que Kubernetes limpie lo suyo antes de morir

La política de recuperación por defecto de un PV creado dinámicamente es
`Delete`, así que **borrar el PVC borra el disco**. El problema es el orden:
Terraform destruye el cluster sin borrar nada dentro.

```hcl
resource "null_resource" "drain_k8s_resources" {
  triggers = { cluster = google_container_cluster.pulse.id }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --wait=true || true
      kubectl delete pvc --all --all-namespaces --wait=true || true
      sleep 60   # dar tiempo a los controladores a liberar los recursos cloud
    EOT
  }
}
```

Con `depends_on` para que corra **antes** de destruir el cluster. Funciona, y es
frágil: depende de un provisioner, de que `kubectl` esté configurado, y de que 60
segundos basten.

### b) No confiar en (a): buscar supervivientes

```bash
#!/usr/bin/env bash
# scripts/verify-cloud-clean.sh
set -euo pipefail
PROJECT=${1:?usage: $0 PROJECT_ID}

leftovers=$(gcloud asset search-all-resources --scope="projects/$PROJECT" \
  --format="value(assetType,displayName)" \
  | grep -vE 'iam.googleapis.com/ServiceAccount|cloudresourcemanager|billingbudgets' || true)

if [ -n "$leftovers" ]; then
  echo "FAIL: recursos facturables aún existen:"
  printf '%s\n' "$leftovers"
  exit 1
fi
echo "OK: nada facturable en $PROJECT"
```

Esto va al grupo `cloud-clean` del harness y se ejecuta **después de cada
`destroy`**, no una vez al mes.

La postura correcta es hacer las dos: (a) para que el caso normal funcione, (b)
porque el caso normal no siempre ocurre y $21 de sorpresa a los 18 días es
barato solo porque el cluster era pequeño.

## Lo que se pregunta en entrevista

**"Ejecutaste `terraform destroy` y sigue llegando factura. ¿Cómo es posible?"**

La respuesta completa: Terraform destruye lo que tiene en estado, y en un cluster
de Kubernetes hay un segundo creador de recursos cloud —el cloud controller y los
drivers CSI— cuyos objetos nunca pasan por Terraform. Destruir el cluster elimina
al propietario y deja los recursos huérfanos. Hace falta limpiar dentro antes de
destruir fuera, **y** una comprobación de supervivientes que no dependa de que
eso haya funcionado.
