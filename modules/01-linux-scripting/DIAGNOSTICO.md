# Diagnóstico — Módulo 01

**Tiempo: 40 min.** Sin documentación, sin buscar en internet, sin autocompletado
de IA.

## Parte A — escribir (20 min)

Escribe desde un archivo en blanco un script `backup-check.sh` que:

1. Reciba un directorio como argumento. Si falta, imprima el uso y salga con 2.
2. Falle con un mensaje claro si el directorio no existe o no es legible.
3. Encuentre todos los archivos `*.tar.gz` modificados en las últimas 24 h.
4. Verifique la integridad de cada uno (`gzip -t`).
5. Imprima un resumen: cuántos revisados, cuántos corruptos.
6. Salga con 0 si todos están bien, 1 si alguno está corrupto.
7. Limpie sus temporales aunque falle a mitad o lo interrumpan con Ctrl-C.
8. Pase `shellcheck` sin avisos.

**Los puntos 7 y 8 son los que separan.** Casi todo el mundo hace del 1 al 6.

## Parte B — diagnosticar (20 min)

Un proceso lleva 10 minutos al 100% de CPU y no escribe logs. Solo tienes su PID.

Escribe la secuencia exacta de comandos que ejecutarías, en orden, para
determinar:

1. Si está haciendo trabajo real o girando en un bucle.
2. Si está bloqueado en I/O, en un lock o en CPU pura.
3. Qué archivos o sockets tiene abiertos.
4. En qué punto del código está, sin tener el código.

Para cada comando, escribe **qué esperas ver si la hipótesis es cierta**. Un
comando sin hipótesis no es diagnóstico, es tanteo.

## Criterio de aprobado

- Parte A: los 8 requisitos. El 7 exige `trap`, el 8 exige comillas correctas.
- Parte B: al menos 4 comandos distintos con hipótesis explícita cada uno, y que
  al menos uno cubra el caso "strace no muestra nada".

## Resultado

- **Aprobado** → labs 00 y 03. Sáltate 01 y 02. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Nota

Si vienes del módulo 31 de `archive/sre-track/`, la parte B debería salirte
sola. La parte A es otra cosa: depurar y escribir son habilidades distintas, y
esa asimetría es justo lo que este diagnóstico busca.
