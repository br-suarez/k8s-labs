# Diagnóstico — Módulo 12

**Tiempo: 35 min.** Sin documentación.

## Parte A — construir (20 min)

Con Pulse desplegado por GitOps y el pipeline del módulo 09:

1. Firma la imagen de `pulse-api` en CI, sin clave estática.
2. Genera un SBOM y adjúntalo como atestación a la imagen, no como artefacto
   suelto del pipeline.
3. Una política de admisión que **rechace** cualquier imagen sin firma válida.
4. Demuestra el rechazo: `kubectl run` con una imagen pública debe fallar.
5. Endurece los pods: no-root, sistema de archivos raíz de solo lectura,
   capacidades eliminadas, seccomp.

El punto 2 es el que separa: un SBOM que vive en el pipeline se pierde; uno
atestado viaja con la imagen y se puede verificar desde el cluster.

## Parte B — razonar (15 min)

1. Tu CI escanea cada imagen que construye. Nombra **tres** clases de imagen
   vulnerable que ese escaneo no cubre.

2. Una imagen sin firmar está corriendo en producción. La política de admisión
   existe, está activa, y si intentas desplegar esa misma imagen ahora te la
   rechaza. ¿Cómo entró?

3. `failurePolicy: Fail` vs `Ignore` en un webhook de admisión. ¿Qué arriesgas
   con cada uno? ¿Cuál eliges y por qué es una decisión incómoda?

4. Firmas una imagen con Cosign. ¿Qué demuestra esa firma exactamente, y qué
   **no** demuestra?

5. Un Secret de Kubernetes está en base64. ¿Qué protege eso? ¿Quién puede leerlo?

## Criterio de aprobado

- Parte A: los 5 puntos, con el rechazo demostrado.
- Parte B: las cinco. **La 2 y la 3 son eliminatorias** — son el break-fix.

## Resultado

- **Aprobado** → labs 00, 04 y 06. (3 bloques)
- **No aprobado** → módulo completo. (5 bloques)

## Nota

Ninguno de los repos de referencia cubre nada de esto. Todo el módulo está
escrito desde cero contra las herramientas actuales, y la pregunta 4 es la que
distingue haber ejecutado `cosign sign` de haber entendido qué firmaste.
