# Break-fix — Módulo 00

## El escenario

Un compañero clonó este repo en su WSL, ejecutó `./scripts/bootstrap.sh` y todo
terminó sin errores. Después ejecutó:

```bash
kind create cluster --config platform/deploy/clusters/lite.yaml
```

El comando se queda colgado varios minutos y termina así:

```
ERROR: failed to create cluster: failed to init node with kubeadm:
command "docker exec --privileged pulse-lite-control-plane kubeadm init ..."
failed with error: exit status 1
```

Justo antes, en la salida detallada:

```
[kubelet-check] The kubelet is not healthy after 4m0s
```

Te pasa además esto, que ejecutó por su cuenta:

```
$ docker ps -a
CONTAINER ID   IMAGE                  STATUS                      NAMES
a3f1c9d2e8b7   kindest/node:v1.36.1   Up 4 minutes                pulse-lite-control-plane
7d4e2a1f9c30   kindest/node:v1.36.1   Exited (137) 2 minutes ago  pulse-lite-worker

$ free -h
               total   used   free  shared  buff/cache   available
Mem:           3.8Gi  3.5Gi  102Mi    12Mi       218Mi        141Mi
Swap:             0B     0B     0B
```

## Tu trabajo

1. Diagnostica la causa. **No la arregles todavía**: escribe primero qué crees
   que pasa y qué comando lo confirmaría.
2. Arréglalo.
3. Escribe el cambio que impediría que le vuelva a pasar a la siguiente persona
   que clone el repo.

Anota en `NOTAS.md` el tiempo hasta el diagnóstico y las pistas que usaste.

## Pistas escalonadas

<details>
<summary>Pista 1</summary>

`Exited (137)` no es un código arbitrario. 137 = 128 + 9, y la señal 9 es
`SIGKILL`. ¿Quién manda `SIGKILL` a un contenedor que nadie ha parado?
</details>

<details>
<summary>Pista 2</summary>

Vuelve a mirar `free -h`, pero la columna `available`, no la columna `free`.
Compárala con lo que `SETUP.md` dice que necesita el perfil `lite`.
</details>

<details>
<summary>Pista 3</summary>

El problema no está dentro de WSL. Está en la configuración del host que decide
cuánta memoria ve WSL. El archivo se llama `.wslconfig` y no vive en el sistema
de archivos de Linux.
</details>

La causa raíz está en `CAUSA-RAIZ.md`. No lo abras hasta haber escrito tu
diagnóstico.
