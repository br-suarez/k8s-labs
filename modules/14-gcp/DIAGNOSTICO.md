# Diagnóstico — Módulo 14

**Tiempo: 30 min.** Sin documentación. **No crees nada mientras lo haces.**

## Parte A — diseñar (15 min)

Sin ejecutar comandos, escribe el diseño:

1. Estructura de proyecto y jerarquía de recursos para Pulse en GCP. ¿Un
   proyecto o varios? Justifica.
2. La cuenta de servicio que usará el pipeline y sus permisos mínimos. Nómbralos.
3. Cómo se autentica el pipeline **sin ninguna clave estática**.
4. Presupuesto y alerta: qué configuras, sobre qué métrica, y a quién notifica.
5. El orden exacto de creación de recursos, y cuál va **primero**.

El punto 5 tiene una respuesta concreta y casi nadie la da bien.

## Parte B — razonar (15 min)

1. `terraform destroy` termina con éxito sobre un cluster GKE. Nombra **cuatro**
   tipos de recurso que pueden seguir existiendo y cobrándote.

2. ¿Por qué esos recursos no estaban en el estado de Terraform si el cluster sí?

3. Recibes un `403` de la API de GCP. Nombra las tres causas distintas y cómo
   las distingues por el mensaje.

4. ¿Qué es workload identity federation y qué sustituye exactamente?

5. Tu presupuesto tiene alerta al 50%, 90% y 100%. Gastaste el triple de lo
   previsto y no te llegó nada. Da dos razones posibles.

## Criterio de aprobado

- Parte A: los 5 puntos, con el 5 correcto.
- Parte B: las cinco. **La 1 y la 2 son eliminatorias** — son el break-fix.

## Resultado

- **Aprobado** → labs 01, 06, 08 y 09. (3 bloques)
- **No aprobado** → módulo completo. (7 bloques)

## La respuesta al punto A.5

**El presupuesto con su alerta, antes que cualquier otro recurso.** Un
presupuesto configurado después de la primera factura sorpresa no sirve de nada,
y es el único recurso de este módulo que no cuesta y que puede ahorrarte dinero.
El lab 01 lo hace primero por eso.
