# Diagnóstico — Módulo 00

**Tiempo: 15 min.** Es el único módulo donde aprobar no te salta contenido: te
confirma que ya lo tienes hecho.

## Prueba

Sin mirar `SETUP.md`:

1. ¿Cuánta RAM tiene tu WSL ahora mismo y qué porcentaje del host representa?
   Un solo comando para la primera parte.
2. Levanta un cluster kind con un control-plane y un worker, comprueba que ambos
   nodos están `Ready`, y destrúyelo. Sin copiar YAML de ningún sitio.
3. Explica en dos frases por qué `sudo snap install kubectl` es mala idea en WSL.

## Criterio de aprobado

Los tres puntos, en 15 minutos, sin documentación abierta.

- **Aprobado** → ejecuta solo el lab 02 (memoria) y cierra el módulo.
- **No aprobado** → módulo completo. Son 2 bloques y es la mejor inversión del
  plan, porque todo lo demás se apoya aquí.

## Trampa habitual

Mucha gente aprueba 1 y 2 y falla el 3. Saber ejecutar no es saber por qué, y el
punto 3 es el que predice si vas a poder depurar el entorno cuando se rompa —
que es justo lo que va a pasar en el break-fix de este módulo.
