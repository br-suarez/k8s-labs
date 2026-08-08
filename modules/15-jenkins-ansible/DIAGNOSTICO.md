# Diagnóstico — Módulo 15

**Tiempo: 30 min.** Sin documentación.

## Parte A — Ansible (20 min)

Escribe un playbook que configure un worker de Pulse en una VM:

1. Instale el binario desde una URL, verificando su checksum.
2. Cree un usuario de servicio sin shell de login.
3. Escriba una unidad de systemd desde plantilla.
4. Escriba la configuración, y **reinicie el servicio solo si cambió**.
5. Sea idempotente: `changed=0` en la segunda ejecución.
6. `--check` debe funcionar sin efectos secundarios.

El punto 4 es el que separa: reiniciar siempre es fácil, reiniciar solo cuando
hace falta requiere handlers y entender cuándo se disparan.

## Parte B — razonar (10 min)

1. Tu playbook reporta `changed=0` en la segunda ejecución. ¿Demuestra que es
   idempotente? Da un caso donde `changed=0` sea una mentira.

2. Una tarea `shell` o `command` siempre reporta `changed`. ¿Cómo lo arreglas, y
   cuál es el riesgo de la solución habitual?

3. Tienes un playbook que parchea los nodos de tu cluster de Kubernetes. ¿Qué
   tiene que hacer **antes** de tocar cada nodo y qué debe respetar?

4. Heredas un Jenkinsfile de 400 líneas. ¿Cuáles son las tres primeras cosas que
   miras?

5. ¿Cuándo NO migrarías de Jenkins?

## Criterio de aprobado

- Parte A: los 6 puntos.
- Parte B: las cinco. **La 1 y la 3 son eliminatorias** — la 3 es el break-fix.

## Resultado

- **Aprobado** → labs 00, 02 y 06. (2 bloques)
- **No aprobado** → módulo completo. (3 bloques)

## Nota

El módulo 28 de `archive/sre-track/` cubre idempotencia, incluido el caso de
Ansible ignorando un fichero de configuración en un montaje escribible por todos.
Si apruebas, sáltate el lab 03 y ve al 06, que es el que ataca el problema nuevo:
Ansible operando sobre un cluster vivo.
