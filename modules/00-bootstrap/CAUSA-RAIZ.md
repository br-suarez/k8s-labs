# Causa raíz — Módulo 00

> Solo después de haber escrito tu diagnóstico en `NOTAS.md`.

## Qué pasaba

El host tiene 8 GB de RAM. WSL2, por defecto, reclama el 50%: 3.8 GiB. El perfil
`lite` necesita unos 2.5 GiB solo para los dos nodos, y el resto se lo comían el
propio `dockerd`, el shell y los procesos de fondo de la distro.

Cuando `kubeadm init` arrancó el plano de control, la presión de memoria hizo que
el OOM killer del kernel matara el contenedor del worker — de ahí el
`Exited (137)`. El control-plane sobrevivió, pero su kubelet no consiguió
estabilizarse sin memoria y `kubeadm` agotó su espera de 4 minutos.

**El síntoma apuntaba a Kubernetes. El fallo era del entorno.** Esa distancia
entre dónde duele y dónde está la causa es exactamente lo que entrena este
break-fix.

## Cómo confirmarlo

```bash
# El OOM killer deja rastro en el log del kernel
dmesg -T | grep -iE 'killed process|out of memory'

# Y en el estado del contenedor
docker inspect pulse-lite-worker --format '{{.State.OOMKilled}} {{.State.ExitCode}}'
# true 137
```

Ese `OOMKilled: true` es el que cierra el diagnóstico. Un `137` con
`OOMKilled: false` significaría otra cosa: alguien o algo externo lo mató.

## La solución

En Windows, `C:\Users\<usuario>\.wslconfig`:

```ini
[wsl2]
memory=6GB
autoMemoryReclaim=gradual
swap=8GB
```

Con 8 GB de host, 6 GB es el techo razonable. Después:

```powershell
wsl --shutdown
```

**`wsl --shutdown` no es opcional.** `.wslconfig` solo se lee al arrancar la VM,
y editarlo sin reiniciar es la causa de la mitad de los "ya lo cambié y sigue
igual".

Con solo 8 GB de host hay que asumir además el perfil `lite` durante todo el
track, y aplicar los valores de retención reducida del módulo 07.

## La prevención

La parte que separa *arreglarlo* de *resolverlo*. Dos cambios:

1. Un check en `platform/scripts/verify.sh` que falle si la memoria disponible
   está por debajo del mínimo del perfil. Lo escribes en el lab 04.
2. `swap=8GB` en `.wslconfig`. No arregla la falta de RAM, pero convierte un
   `SIGKILL` inmediato en una degradación lenta y diagnosticable — que en una
   guardia es la diferencia entre "se murió" y "va lento, vamos a mirar".

## Por qué este fallo está aquí

Es el fallo más probable que te vas a encontrar de verdad en este track, y está
en el módulo 00 a propósito: si te va a pasar, que te pase ahora y no en la
semana 11 con el stack de observabilidad a medio montar.
