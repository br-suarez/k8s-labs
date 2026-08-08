# Break-fix — Módulo 15

## El escenario

Un playbook parchea los nodos del cluster todos los martes a las 02:00. Lleva
cuatro meses funcionando. Anoche tumbó Pulse durante 18 minutos.

```
PLAY [Patch cluster nodes] *****************************************************

TASK [Cordon node] *************************************************************
changed: [node-1]
changed: [node-2]
changed: [node-3]

TASK [Drain node] **************************************************************
changed: [node-1]
changed: [node-2]
changed: [node-3]

TASK [Apply OS updates] ********************************************************
changed: [node-1]
changed: [node-2]
changed: [node-3]

TASK [Reboot] ******************************************************************
changed: [node-1]
changed: [node-2]
changed: [node-3]

PLAY RECAP *********************************************************************
node-1  : ok=6  changed=4  unreachable=0  failed=0
node-2  : ok=6  changed=4  unreachable=0  failed=0
node-3  : ok=6  changed=4  unreachable=0  failed=0
```

Cero fallos. Todo `ok`.

## El playbook

```yaml
- name: Patch cluster nodes
  hosts: k8s_nodes
  become: true

  tasks:
    - name: Cordon node
      command: kubectl cordon {{ inventory_hostname }}
      delegate_to: localhost

    - name: Drain node
      command: >
        kubectl drain {{ inventory_hostname }}
        --ignore-daemonsets
        --delete-emptydir-data
        --force
        --disable-eviction
        --timeout=120s
      delegate_to: localhost

    - name: Apply OS updates
      apt:
        upgrade: dist
        update_cache: true

    - name: Reboot
      reboot:
        reboot_timeout: 600

    - name: Uncordon node
      command: kubectl uncordon {{ inventory_hostname }}
      delegate_to: localhost
```

## Lo que pasó en el cluster

```
02:00:04  node-1 cordoned    02:00:04  node-2 cordoned    02:00:05  node-3 cordoned
02:00:31  todos los pods de pulse-api en Pending
02:18:47  node-1 vuelve, pods programados
```

Durante 18 minutos no había ningún nodo disponible.

## Tu trabajo

1. ¿Por qué se drenaron los tres nodos a la vez? Falta **una** palabra en el
   playbook.
2. `--disable-eviction`. ¿Qué hace y qué te acabas de saltar? Relaciónalo con el
   módulo 06.
3. `--force`. ¿Qué pods afecta que los demás flags no afecten? ¿Por qué es
   peligroso?
4. ¿Por qué el recap dice `failed=0` si el servicio estuvo caído 18 minutos?
5. Arréglalo. El parcheo debe completarse sin que Pulse pierda disponibilidad.
6. ¿Cómo compruebas, dentro del propio playbook, que es seguro continuar al
   siguiente nodo?
7. Lleva cuatro meses funcionando. ¿Por qué falló justo anoche?

## Pistas escalonadas

<details><summary>Pista 1</summary>

Ansible ejecuta cada tarea contra **todos** los hosts del grupo antes de pasar a
la siguiente. ¿Qué directiva cambia eso para que procese los hosts de N en N?
</details>

<details><summary>Pista 2 — para el punto 2</summary>

El drenaje normal usa la API de *eviction*, que es la que consulta los
PodDisruptionBudgets. ¿Qué pasa si la desactivas y borras los pods directamente?
Los PDBs del módulo 06 estaban ahí para esto.
</details>

<details><summary>Pista 3 — para el punto 4</summary>

Ansible reporta el resultado de **sus tareas**. `kubectl drain` devolvió 0. La
salud del servicio no es algo que ninguna de esas tareas mida.
</details>

<details><summary>Pista 4 — para el punto 7</summary>

Cuatro meses funcionando y falla ahora. ¿Qué cambió recientemente en el cluster?
Piensa en cuántas réplicas tenía Pulse antes y cuántas tiene desde que
configuraste el HPA y el anti-affinity del módulo 06.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Porque es donde Ansible y Kubernetes chocan. Ansible es imperativo y procedural:
hace lo que le dices, en el orden que le dices, y reporta si el comando salió
bien. Kubernetes es declarativo y asíncrono: un comando que devuelve 0 no
significa que el sistema haya convergido.

Un playbook que trata a un cluster como una lista de máquinas puede ejecutar
perfectamente y provocar una caída completa, con `failed=0` en el recap.
