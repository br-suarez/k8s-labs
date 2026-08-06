# Diagnóstico — Módulo 13

**Tiempo: 35 min.** Sin documentación.

## Parte A — construir (20 min)

Sin tocar la nube todavía:

1. Un módulo reutilizable con variables validadas, salidas, y versión fijada.
2. Consúmelo desde dos entornos que difieran en al menos tres parámetros.
3. Backend remoto con bloqueo de estado.
4. `terraform plan -detailed-exitcode` integrado en CI: falla si hay deriva.
5. Un `precondition` o `lifecycle` que impida un cambio destructivo por accidente.

El punto 5 es el que separa. Casi nadie lo pone hasta que un `plan` propone
destruir una base de datos y alguien lo aprueba.

## Parte B — razonar (15 min)

1. `terraform plan` dice "No changes". La infraestructura real está rota.
   Nombra **tres** formas en que eso puede ser cierto a la vez.

2. Dos pipelines ejecutan `apply` a la vez. El segundo falla con un error de
   bloqueo. Un compañero añade `-lock=false` para que deje de fallar. Describe
   qué pasa las siguientes tres semanas.

3. ¿Qué diferencia hay entre `terraform plan` y `terraform plan -refresh-only`?
   Da un caso donde apunten en direcciones opuestas sobre el mismo campo.

4. Cambias una etiqueta y el plan dice `1 to add, 1 to destroy` sobre tu base de
   datos. ¿Qué pasó y qué haces?

5. `terraform destroy` termina con éxito. ¿Qué puede seguir existiendo y
   cobrándote?

## Criterio de aprobado

- Parte A: los 5 puntos.
- Parte B: las cinco. **La 2 y la 5 son eliminatorias** — la 2 es el break-fix de
  este módulo y la 5 el del siguiente.

## Resultado

- **Aprobado** → labs 00, 04 y 08. (3 bloques)
- **No aprobado** → módulo completo. (5 bloques)

## Nota

El módulo 27 de `archive/sre-track/` ya cubre `import` y deriva, incluido el caso
de `plan` vs `plan -refresh-only` apuntando en direcciones opuestas. Si apruebas,
sáltate los labs 05 y 06 y dedica el tiempo al 07 y al 08, que son nuevos.
