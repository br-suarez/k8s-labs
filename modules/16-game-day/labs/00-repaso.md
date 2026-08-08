# Lab 16.00 — Reconstrucción completa, cronometrada

**CORE · 60 min**

## Contexto

El repaso final es el más honesto del track: no responde preguntas, levanta el
sistema entero. Trece capas, desde un cluster vacío.

## El ejercicio

```bash
kind delete cluster --name pulse
```

Y desde ahí, hasta que `./platform/scripts/verify.sh` pase entero. **Cronometra.**

Puedes usar todo lo que construiste: Terraform del módulo 13, el app-of-apps del
10, los checkpoints del script de checkpoint. De hecho, deberías — si no puedes,
esa es la conclusión del ejercicio.

## Qué anotar

| Medida | Valor |
|---|---|
| Tiempo total | |
| Pasos manuales | |
| Qué tuve que buscar | |
| Qué falló al primer intento | |
| Comparación con el módulo 08c lab 00 | |

La última fila es la interesante: entonces eran siete capas y ahora son trece.
Si el tiempo no ha subido proporcionalmente, la automatización está haciendo su
trabajo.

## El objetivo

Por debajo de **30 minutos** hasta verde, con menos de tres pasos manuales.

Si no llegas, no pasa nada — pero anota exactamente dónde se fue el tiempo. Cada
paso manual es una tarea de remediación para el postmortem del lab 04.

## Después

Deja el sistema **sano y verificado** antes del lab 01. Los cinco fallos que
vienen se inyectan sobre algo que funciona; si ya estaba roto, el ejercicio no
mide nada.

```bash
./platform/scripts/verify.sh
```

Los doce grupos en verde o saltando limpiamente.
