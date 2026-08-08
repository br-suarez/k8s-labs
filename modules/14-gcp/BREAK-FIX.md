# Break-fix — Módulo 14

## El escenario

Terminaste el módulo. Destruiste todo:

```
$ terraform destroy -auto-approve
...
Destroy complete! Resources: 14 destroyed.

$ terraform state list
$ echo "estado vacío: $?"
estado vacío: 0
```

Catorce recursos destruidos, estado vacío. Cerraste el portátil tranquilo.

**Dieciocho días después**, la factura:

```
Compute Engine
  Storage PD Capacity                        14.20 GB-month      $0.56
  Storage SSD Capacity                       60.00 GB-month      $10.20
  Network Load Balancing: Forwarding Rule    432 hours           $9.94
  Static IP Charge (unused)                  432 hours           $1.04
Cloud Storage
  Standard Storage                            2.10 GB-month      $0.04
                                                        Total   $21.78
```

Veintiún dólares por infraestructura que creías destruida. Y sigue corriendo.

## Lo que encuentras

```
$ gcloud compute disks list
NAME                                      ZONE           SIZE_GB  STATUS
gke-pulse-prod-pvc-a3f9c21b-4b8e-4d1a     us-central1-a  50       READY
gke-pulse-prod-pvc-c7d1e59f-2a4b-8c30     us-central1-a  10       READY

$ gcloud compute forwarding-rules list
NAME                              REGION       IP_ADDRESS      TARGET
a3f9c214b8e4d1a9f02c7d1e59f2a4b   us-central1  34.72.118.204   us-central1/targetPools/...

$ gcloud compute addresses list
NAME                              ADDRESS         STATUS
a3f9c214b8e4d1a9f02c7d1e59f2a4b   34.72.118.204   IN_USE
```

Ninguno aparece en tu código Terraform. Ninguno estaba en el estado.

Y el presupuesto que configuraste en el lab 01, con alertas al 50%, 90% y 100%
de $30:

```
$ gcloud billing budgets list --billing-account=XXXXXX-XXXXXX-XXXXXX
displayName: pulse-budget
amount: {specifiedAmount: {currencyCode: USD, units: '30'}}
thresholdRules:
- thresholdPercent: 0.5
- thresholdPercent: 0.9
- thresholdPercent: 1.0
notificationsRule:
  monitoringNotificationChannels: []
```

No te llegó ninguna alerta.

## Tu trabajo

1. ¿De dónde salieron los discos? Mira sus nombres — te lo están diciendo.
2. ¿Y la regla de reenvío y la IP estática?
3. **La pregunta central:** ¿por qué Terraform no los destruyó si destruyó el
   cluster que los contenía?
4. ¿Por qué no estaban en el estado, si el cluster GKE sí lo estaba?
5. ¿Por qué no llegó ninguna alerta de presupuesto? Hay **dos** razones
   independientes, y una está a la vista arriba.
6. Límpialo. Y luego: ¿cómo compruebas que no queda nada más?
7. Arregla el proceso para que `terraform destroy` sea suficiente la próxima vez.
   Hay dos enfoques y no son excluyentes.

## Pistas escalonadas

<details><summary>Pista 1</summary>

`gke-pulse-prod-pvc-a3f9c21b...`. El prefijo `pvc` no es casualidad. ¿Qué creaste
en el cluster que necesitara almacenamiento persistente?
</details>

<details><summary>Pista 2</summary>

Terraform creó el cluster GKE. Pero, ¿quién creó los discos? No fuiste tú
directamente, y no fue Terraform. Piensa en qué componente de GKE reacciona
cuando aplicas un `PersistentVolumeClaim` o un `Service` de tipo
`LoadBalancer`.
</details>

<details><summary>Pista 3 — para el punto 5</summary>

Mira `monitoringNotificationChannels: []`. Esa es una de las dos razones. La otra
tiene que ver con **cuándo** se evalúa un presupuesto y con qué retraso llega el
dato de facturación.
</details>

<details><summary>Pista 4 — para el punto 7</summary>

Un enfoque es asegurarte de que Kubernetes limpie lo suyo antes de que Terraform
destruya el cluster — ¿qué le pasa a un PVC con su política de recuperación por
defecto? El otro es no depender de eso y buscar supervivientes activamente.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Porque es la factura sorpresa clásica, y porque enseña un límite estructural:
**Terraform solo destruye lo que creó.** En un cluster de Kubernetes hay un
segundo creador de recursos cloud —el propio cluster— y ese no aparece en ningún
estado de Terraform.

Con $30 al mes el daño es anecdótico. Con un cluster de producción y discos SSD,
la misma omisión son miles de dólares al mes durante meses.
