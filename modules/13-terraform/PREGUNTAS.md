# Preguntas de entrevista — Módulo 13

## Estado

**1. ¿Por qué existe el bloqueo de estado y qué pasa exactamente sin él?**

<details><summary>Guía</summary>

Terraform lee el estado entero, planifica, actúa y lo escribe entero. Sin
bloqueo, dos `apply` concurrentes producen una escritura perdida: ambos leen la
misma copia, ambos escriben, y el segundo sobrescribe lo que registró el primero.
Los recursos que creó el primero **existen en la nube y desaparecen del estado**.
Terraform querrá crearlos de nuevo y fallará con "already exists". El error de
bloqueo no es un fallo, es el mecanismo funcionando.
</details>

**2. `terraform plan` dice "No changes" y la infraestructura está rota. Tres
formas.**

<details><summary>Guía</summary>

(a) El recurso está roto por dentro pero sus atributos gestionados no cambiaron —
un proceso caído en una VM cuya definición sigue siendo correcta. (b) Alguien
modificó algo que tu configuración no declara: Terraform solo compara los campos
que gestiona. (c) El recurso no está en el estado en absoluto, así que Terraform
no lo mira. La tercera es la del break-fix, y la más difícil de ver porque no hay
ninguna señal.
</details>

**3. `plan` vs `plan -refresh-only`. Un caso donde apunten en direcciones
opuestas.**

<details><summary>Guía</summary>

`plan` compara configuración contra estado y propone cambiar la **realidad**.
`-refresh-only` compara realidad contra estado y propone actualizar el
**estado**. Alguien cambia a mano el tamaño de una instancia: `plan` dice "voy a
devolverla a lo que dice el código", `-refresh-only` dice "voy a anotar que ahora
es más grande". Sobre el mismo campo, direcciones opuestas — y elegir mal
significa o pisar un cambio legítimo o legitimar uno no autorizado.
</details>

## Cambios destructivos

**4. Cambias una etiqueta y el plan propone destruir y recrear tu base de datos.**

<details><summary>Guía</summary>

Ese atributo es `ForceNew` en el proveedor: no se puede modificar en caliente, así
que el único camino es reemplazar. Qué haces: **no aplicar**, leer qué atributo
lo dispara (`# forces replacement` en el plan), y buscar alternativa — a veces el
cambio se puede hacer fuera de Terraform e importar, a veces hay que aceptar una
ventana de mantenimiento. Protección previa:
`lifecycle { prevent_destroy = true }` en recursos con estado, que convierte el
accidente en un error de plan.
</details>

**5. ¿Qué te da `prevent_destroy` y cuál es su límite?**

<details><summary>Guía</summary>

Hace fallar cualquier plan que proponga destruir ese recurso, incluido un
reemplazo. El límite: no impide `terraform destroy` si primero quitas el bloque,
y no protege de que alguien borre el recurso fuera de Terraform. Es una barrera
contra el error, no contra la intención — que es exactamente para lo que sirve.
</details>

## Módulos y versiones

**6. `version = "~> 3.0"` en un módulo. ¿Qué puede romperse y cuándo?**

<details><summary>Guía</summary>

`~> 3.0` permite cualquier 3.x, así que un `terraform init` futuro puede traer
3.9 con comportamiento distinto — y si ese cambio toca un atributo `ForceNew`,
un plan rutinario propone recrear recursos. Se fija exacto (`= 3.4.1`) y se
renueva de forma deliberada con un PR, igual que las imágenes por digest del
módulo 03. El patrón es el mismo: fijar **y** renovar automáticamente, no fijar y
olvidar.
</details>

**7. ¿Cuándo un módulo deja de merecer la pena?**

<details><summary>Guía</summary>

Cuando tiene más variables que recursos, o cuando cada consumidor pasa un valor
distinto a casi todas — señal de que estás construyendo una capa de
indirección sobre el proveedor sin añadir abstracción. Un módulo bueno encapsula
una **decisión** (cómo desplegamos aquí un servicio web), no una envoltura fina
sobre un recurso.
</details>

## Operación

**8. `terraform destroy` termina bien. ¿Qué puede seguir cobrándote?**

<details><summary>Guía</summary>

Todo lo que Terraform no tenga en el estado: recursos creados por otro sistema
—discos persistentes que creó Kubernetes al vincular un PVC, balanceadores que
creó un Service de tipo LoadBalancer—, recursos huérfanos por un estado
corrompido, snapshots y backups automáticos, IPs estáticas reservadas, y logs o
métricas retenidos. Es el break-fix del módulo 14 y la razón de que `destroy`
tenga que ir seguido de una búsqueda activa de supervivientes.
</details>

**9. Un `apply` se cancela a mitad. ¿En qué estado queda todo?**

<details><summary>Guía</summary>

Indeterminado y peligroso: pueden existir recursos creados que no llegaron a
escribirse en el estado. Terraform intenta persistir de forma incremental, pero
una interrupción brusca —un runner de CI cancelado— deja huérfanos. Por eso
`cancel-in-progress: false` en el pipeline de infraestructura, al revés que en el
de aplicación: cancelar un build es gratis, cancelar un `apply` crea deuda
invisible.
</details>

**10. ¿Cuándo es legítimo `force-unlock`?**

<details><summary>Guía</summary>

Solo cuando tienes certeza de que el proceso que tomó el bloqueo ya no existe —
un runner que murió, una máquina apagada. La información del bloqueo dice quién y
cuándo; se usa para comprobarlo, no para saltárselo. Hacerlo mientras otro
`apply` corre de verdad produce dos procesos que creen tener el bloqueo, que es
peor que el problema que intentabas resolver.
</details>
