# Preguntas de entrevista — Módulo 14

## El límite de la IaC

**1. `terraform destroy` termina bien y la factura sigue llegando. ¿Cómo?**

<details><summary>Guía</summary>

Terraform destruye lo que tiene en su estado. En un cluster de Kubernetes hay un
segundo creador de recursos cloud: el cloud controller manager y los drivers CSI
crean balanceadores, reglas de reenvío, IPs y discos persistentes cuando aplicas
Services de tipo LoadBalancer y PVCs. Esos objetos nunca pasan por Terraform.
Destruir el cluster elimina al propietario y deja los recursos huérfanos, sin que
nadie los siga gestionando.
</details>

**2. ¿Cómo compruebas que un proyecto no tiene nada facturable?**

<details><summary>Guía</summary>

`gcloud asset search-all-resources --scope=projects/ID`, que inventaría todo sin
depender de recordar cada tipo de recurso. Enumerar servicio por servicio
(`compute disks list`, `forwarding-rules list`, …) siempre deja algo fuera —
snapshots, imágenes, buckets, logs retenidos. Y se ejecuta **después de cada
destroy**, automatizado, no cuando llega la factura.
</details>

**3. ¿Qué le pasa a un disco creado dinámicamente cuando borras el PVC?**

<details><summary>Guía</summary>

Depende de la `reclaimPolicy` del StorageClass. `Delete` por defecto en la
mayoría de clases dinámicas: borrar el PVC borra el PV y el disco subyacente.
`Retain` conserva el disco, que es lo que quieres para datos que no puedes
perder — y también la forma de acumular discos huérfanos sin darte cuenta. El
matiz que importa: si destruyes el cluster **sin** borrar los PVCs, ninguna
política se aplica, porque no queda nadie para aplicarla.
</details>

## Costes

**4. Un presupuesto de GCP con alertas al 50/90/100% no avisó. Dos razones.**

<details><summary>Guía</summary>

(a) No hay canal de notificación asociado, o lo hay y nunca se verificó — GCP
manda un correo de confirmación que hay que pulsar, y sin eso el canal no recibe
nada. (b) Los datos de facturación se consolidan con horas de retraso, así que la
evaluación va por detrás del gasto real. Conclusión importante: **un presupuesto
no es un límite, es una alarma retrasada.** Para un tope duro hace falta una
función que reaccione al evento y desactive la facturación del proyecto.
</details>

**5. ¿Qué es el coste por unidad y por qué es mejor que el coste total?**

<details><summary>Guía</summary>

Coste dividido entre unidades de trabajo — para Pulse, coste por 1.000 sondeos.
El total sube cuando creces, así que no distingue "estamos gastando de más" de
"estamos haciendo más". El coste por unidad sí: si sube mientras el volumen sube,
la eficiencia empeora. Es la única forma en que el coste se compara entre
periodos, entre servicios y contra ingresos, y es lo que permite que un SRE
participe en la conversación de capacidad.
</details>

**6. Pides 2 vCPU y usas 0.3. ¿Cuánto cuesta ese hueco al año y qué haces?**

<details><summary>Guía</summary>

Se calcula: la diferencia por el precio del recurso por el número de réplicas por
las horas del año. Lo que se busca es que sepas que el `request` es lo que
**reserva** capacidad y por tanto lo que se paga en un modelo por nodo, no el uso
real. El arreglo es ajustar requests a lo medido con margen —el percentil alto de
uso, no la media— y comprobar el efecto en el binpacking. Cuidado con recortar de
más: un request demasiado bajo provoca desalojos, y ahí ya no estás optimizando
coste sino comprando incidentes.
</details>

## Identidad y errores

**7. ¿Qué es workload identity federation y qué sustituye?**

<details><summary>Guía</summary>

Sustituye la clave JSON de cuenta de servicio guardada en un secreto de CI.
Establece una relación de confianza con un emisor OIDC externo —el de GitHub
Actions— de forma que un token efímero del workflow se intercambia por
credenciales de corta vida. No hay clave que rotar, filtrar ni revocar. La
condición de atributos es la parte crítica: sin restringir `repository` y `ref`,
un proveedor que confía solo en el emisor acepta tokens de **cualquier**
repositorio de GitHub.
</details>

**8. Un `403` de la API de GCP. Tres causas y cómo las distingues.**

<details><summary>Guía</summary>

(a) La API no está habilitada en el proyecto — el mensaje lo dice explícitamente
y sugiere el comando para activarla. (b) Falta un permiso de IAM — el mensaje
nombra el permiso concreto que falta, que es lo que hay que leer en vez de dar
Owner. (c) Cuota o restricción de política de organización — el mensaje habla de
límite o de constraint. Leer el mensaje completo distingue las tres en segundos;
la reacción de "dale Owner y ya" resuelve una de las tres y crea un problema de
seguridad.
</details>

## Portabilidad

**9. Mapea VPC, IAM, GKE y Cloud Storage a AWS y Azure. ¿Dónde se rompe la
analogía?**

<details><summary>Guía</summary>

VPC ↔ VPC ↔ VNet; IAM ↔ IAM ↔ Entra ID + RBAC; GKE ↔ EKS ↔ AKS; GCS ↔ S3 ↔ Blob
Storage. Se rompe en el modelo de identidad: el IAM de GCP concede roles sobre
recursos en una jerarquía de organización/carpeta/proyecto, el de AWS usa
políticas sobre principals con límites de permisos, y Azure separa identidad
(Entra) de autorización (RBAC). Traducir permisos entre nubes literalmente es
donde se cometen los errores de seguridad más caros, porque las primitivas no
coinciden.
</details>

**10. ¿Qué NO harías multi-cloud, y por qué?**

<details><summary>Guía</summary>

Una capa de abstracción propia sobre las tres, para no atarte. Cuesta el mínimo
común denominador de las tres, se rompe en cada actualización de proveedor, y la
portabilidad que compra rara vez se usa. Lo defendible es mantener portable lo
que ya lo es —contenedores, manifiestos de Kubernetes, Terraform con módulos por
proveedor— y aceptar el acoplamiento en lo gestionado, que es precisamente donde
está el valor de usar una nube.
</details>
