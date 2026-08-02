# Diagnóstico — Módulo 08b

**Tiempo: 25 min.** Corto, como los del 05 y el 08.

## Aviso

Tercer módulo donde **suspender es lo esperado**. eBPF es una tecnología de
kernel y la mayoría de los SRE la han usado a través de herramientas sin
entender qué hay debajo.

Si lo suspendes no dice nada de tu nivel. Hazlo para saber por dónde vas.

## Prueba

Sin documentación:

1. En una frase: ¿qué es eBPF y por qué es seguro cargar código en el kernel?
   La respuesta correcta contiene una palabra concreta.

2. Un proceso está corriendo en producción. No puedes reiniciarlo, no puedes
   recompilarlo, no puedes añadirle logs. Necesitas saber **qué archivos abre**.
   Da dos formas de averiguarlo y di cuál tiene menos impacto.

3. ¿Qué es un mapa (map) de eBPF y por qué hace falta?

4. Tu aplicación reporta un p99 de 40 ms. El cliente mide 4 segundos. La red
   está bien y la respuesta es pequeña. Nombra **dos** sitios donde puede estar
   el tiempo, sabiendo que ninguno aparece en tus trazas.

5. ¿Qué es un flamegraph y qué representa el **eje horizontal**? (Casi todo el
   mundo se equivoca en esta.)

6. eBPF frente a instrumentación con OpenTelemetry: da una cosa que cada uno
   pueda hacer y el otro no.

## Criterio de aprobado

Las seis. **La 4 y la 5 son eliminatorias.** La 4 es el break-fix de este módulo;
la 5 distingue haber mirado flamegraphs de haberlos entendido.

## Resultado

- **Aprobado** → labs 00, 03 y 04. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Sobre la pregunta 5

El eje horizontal de un flamegraph **no es tiempo**. Es la proporción de muestras
en las que esa función estaba en la pila, ordenadas alfabéticamente para agrupar
lo que es igual. Un frame más ancho significa "aparecía en más muestras", no
"tardó más" ni "se ejecutó después". Leerlo como una línea temporal —que es lo
que sugiere la forma— lleva a conclusiones falsas.
