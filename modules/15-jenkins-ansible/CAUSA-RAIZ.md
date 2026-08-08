# Causa raíz — Módulo 15

> Solo después de haber escrito tu diagnóstico.

## 1. La palabra que falta: `serial`

Ansible ejecuta cada tarea contra **todos** los hosts del grupo antes de pasar a
la siguiente. Es su modelo de ejecución por defecto y es exactamente lo que
quieres para configurar cincuenta servidores idénticos.

Aplicado a un cluster, significa: cordonar los tres, luego drenar los tres, luego
actualizar los tres.

```yaml
- name: Patch cluster nodes
  hosts: k8s_nodes
  serial: 1        # ← de uno en uno
```

Con `serial: 1`, el play completo se ejecuta contra un host antes de empezar con
el siguiente. Una palabra.

`serial: "25%"` también vale para flotas grandes, pero para nodos de Kubernetes
la respuesta suele ser 1: la unidad de fallo es el nodo y quieres el mínimo
impacto simultáneo.

## 2. `--disable-eviction`: te saltaste los PDBs

El drenaje normal usa la **Eviction API**, que es la que consulta los
PodDisruptionBudgets. Si un desalojo violaría un PDB, la API lo rechaza y
`kubectl drain` espera y reintenta.

`--disable-eviction` cambia eso por un `DELETE` directo sobre los pods. El PDB
**no se consulta en absoluto**.

Es decir: hiciste el trabajo del módulo 06 —definir PDBs para que el
mantenimiento no tumbara el servicio— y luego pasaste un flag que los ignora.

Ese flag existe para casos donde el drenaje se atasca de verdad y hay que forzar.
Ponerlo por defecto en un playbook periódico es desactivar el mecanismo de
seguridad de forma permanente. **Mismo patrón que `-lock=false` en el módulo 13 y
`selfHeal=false` en el 10**: el control estorbaba, se desactivó, nadie volvió.

## 3. `--force`: los pods sin controlador

`--force` permite borrar pods **no gestionados por un controlador** — pods sueltos
creados directamente, sin Deployment, ReplicaSet ni StatefulSet detrás.

Sin `--force`, `drain` se niega a continuar y te avisa de que existen. Con
`--force`, los borra y **no vuelven nunca**, porque no hay nada que los recree.

Peligroso porque es silencioso: un pod de depuración que alguien dejó, un job
manual a medias, un pod de una herramienta que se despliega así. Desaparecen sin
rastro más allá de una línea en la salida.

## 4. `failed=0` con el servicio caído

Ansible reporta el resultado de **sus tareas**:

- `kubectl cordon` → exit 0 → `changed`
- `kubectl drain` → exit 0 → `changed`
- `apt upgrade` → exit 0 → `changed`
- `reboot` → el host volvió → `changed`

Todo correcto. Ninguna tarea preguntó "¿está Pulse sirviendo tráfico?", porque
nadie se lo pidió.

Aquí está la diferencia de modelos que da nombre al módulo: **Ansible es
imperativo y síncrono; Kubernetes es declarativo y asíncrono.** Un comando que
devuelve 0 significa que la petición fue aceptada, no que el sistema haya
convergido a un estado bueno. Un playbook que no comprueba convergencia puede
ejecutarse perfectamente mientras destruye el servicio.

## 5. El playbook corregido

```yaml
- name: Patch cluster nodes
  hosts: k8s_nodes
  become: true
  serial: 1                      # ← uno cada vez
  max_fail_percentage: 0         # ← para todo si uno falla

  pre_tasks:
    - name: Verify the cluster is healthy before touching anything
      command: ./platform/scripts/verify.sh k8s
      delegate_to: localhost
      changed_when: false

  tasks:
    - name: Cordon node
      command: kubectl cordon {{ inventory_hostname }}
      delegate_to: localhost
      changed_when: true

    - name: Drain node, respecting PodDisruptionBudgets
      command: >
        kubectl drain {{ inventory_hostname }}
        --ignore-daemonsets
        --delete-emptydir-data
        --timeout=600s
      delegate_to: localhost
      register: drain_result
      failed_when: drain_result.rc != 0     # si los PDBs lo bloquean, PARA

    - name: Apply OS updates
      apt:
        upgrade: dist
        update_cache: true

    - name: Reboot
      reboot:
        reboot_timeout: 600

    - name: Wait for the node to be Ready
      command: kubectl wait --for=condition=Ready node/{{ inventory_hostname }} --timeout=300s
      delegate_to: localhost
      changed_when: false

    - name: Uncordon node
      command: kubectl uncordon {{ inventory_hostname }}
      delegate_to: localhost

  post_tasks:
    - name: Verify the service recovered before moving to the next node
      command: ./platform/scripts/verify.sh k8s slo
      delegate_to: localhost
      changed_when: false
      retries: 10
      delay: 30
      register: health
      until: health.rc == 0
```

Cambios que importan:

| Cambio | Por qué |
|---|---|
| `serial: 1` | Un nodo cada vez |
| Sin `--disable-eviction` | Los PDBs vuelven a decidir |
| Sin `--force` | Un pod sin controlador **detiene** el proceso para que lo mires |
| `--timeout=600s` | Tiempo real para que los PDBs permitan el desalojo |
| `failed_when` explícito | Un drenaje bloqueado es un fallo, no un aviso |
| `kubectl wait` tras el reinicio | Convergencia, no solo "el host respondió" |
| `post_tasks` con reintentos | **No avanza hasta que el servicio esté sano** |
| `max_fail_percentage: 0` | Si un nodo va mal, no se tocan los demás |

El `post_tasks` con `until` es el corazón del arreglo: convierte un playbook que
ejecuta comandos en uno que **verifica estado**, que es lo que hace falta al
operar sobre un sistema declarativo.

## 6. Cómo comprobar que es seguro seguir

La respuesta es reutilizar el harness que llevas construyendo desde el módulo 01:

```yaml
- command: ./platform/scripts/verify.sh k8s slo
  retries: 10
  delay: 30
  until: health.rc == 0
```

No hay que escribir lógica de salud nueva. Ya existe, ya se ejecuta en CI, y ya
sabe qué significa "Pulse está sano".

## 7. Por qué falló justo anoche

Cuatro meses funcionando con `serial` ausente. La diferencia no está en el
playbook: está en el cluster.

Antes, Pulse corría con réplicas suficientes repartidas de forma que quedaba
capacidad al drenar. Desde que configuraste el **anti-affinity** del módulo 06,
las réplicas de `pulse-api` están obligatoriamente en nodos distintos — una por
nodo, tres nodos.

Drenar los tres a la vez ahora significa desalojar el 100% de las réplicas
simultáneamente. Antes, con las réplicas mal repartidas, quedaba alguna por
casualidad.

**El playbook siempre estuvo roto. Lo que cambió fue que dejó de tener suerte.**

Es un tipo de fallo que conviene reconocer: un cambio correcto en un sistema
—repartir réplicas para mejorar la disponibilidad— expone un defecto latente en
otro. Y en el postmortem el instinto es culpar al cambio reciente, cuando el
defecto llevaba cuatro meses ahí.
