# Lab 08b.00 — Reconstrucción completa, cronometrada

**CORE · 20 min**

## Contexto

Antes de romper nada, comprueba que puedes construirlo. Es el repaso más honesto
que existe: no responde preguntas, levanta el sistema.

## El ejercicio

Desde un cluster vacío, deja Pulse corriendo con todo lo de los módulos 00–08.
**Cronometra.**

```bash
kind delete cluster --name pulse
kind create cluster --config platform/deploy/clusters/standard.yaml
# ... y a partir de aquí, tú
```

Objetivo: por debajo de 25 minutos hasta que `./platform/scripts/verify.sh`
pase entero.

## Qué anotar

| Medida | Valor |
|---|---|
| Tiempo total | |
| Pasos que necesitaron intervención manual | |
| Qué tuve que buscar | |
| Qué falló al primer intento | |

Las dos últimas filas son las importantes. Todo lo que hayas tenido que buscar
es material directo para el repaso de 90 días, y todo paso manual es un candidato
a automatizar en el módulo 10.

## Si no llegas a 25 minutos

No pasa nada, pero anótalo. Si la causa es que el despliegue tiene pasos manuales
frágiles, acabas de encontrar el argumento para GitOps que el módulo 10 va a
formalizar — y lo encontraste tú, que es mejor que leerlo.

## Después

Deja el sistema **sano y verificado** antes de pasar al lab 01. Inyectar fallos
sobre algo que ya estaba roto convierte el ejercicio en ruido.

```bash
./platform/scripts/verify.sh
```
