# Preguntas de entrevista — Módulo 12

## Admisión

**1. Tienes una política de admisión activa y algo que la incumple corriendo en
producción. ¿Es una contradicción?**

<details><summary>Guía</summary>

No. La admisión es un **control de flujo**: evalúa lo que entra, en el momento de
entrar. No reevalúa lo que ya está, y tiene una ventana de fallo configurable
—`failurePolicy`— durante la cual puede admitir sin verificar. Para el estado del
cluster hace falta un control aparte: escaneo en segundo plano que produzca
informes de cumplimiento. Confundir los dos es creer que instalar el controlador
te dio cumplimiento cuando te dio una puerta.
</details>

**2. `failurePolicy: Fail` vs `Ignore`. Elige y defiéndelo.**

<details><summary>Guía</summary>

`Ignore`: si el webhook no responde, se admite sin verificar — hueco silencioso.
`Fail`: si no responde, no se admite nada — riesgo de indisponibilidad, y en el
caso extremo un deadlock de arranque, porque el pod del propio webhook necesita
pasar por el webhook. La postura defendible es `Fail` **con exclusiones mínimas
y explícitas** para los namespaces del plano de control, más alta disponibilidad
del webhook para que la ventana tienda a cero. Lo importante es saber que estás
eligiendo entre disponibilidad y seguridad, no tropezarte con la elección.
</details>

**3. Tu regla dice `imageReferences: ["ghcr.io/miorg/*"]`. ¿Qué pasa con una
imagen de Docker Hub?**

<details><summary>Guía</summary>

Nada: la regla no coincide, así que no opina, y el pod se admite. Es un fallo
abierto por omisión, y al revés de lo que quieres — el riesgo mayor está en las
imágenes que **no** controlas. Se escribe `["*"]` con una lista de excepciones
explícita y auditable.
</details>

## Firma y procedencia

**4. Firmas una imagen con Cosign. ¿Qué demuestra y qué no?**

<details><summary>Guía</summary>

Demuestra que quien tenía esa clave —o esa identidad OIDC, en keyless— firmó
**ese digest**, y que el digest no ha cambiado desde entonces. No demuestra que
la imagen sea segura, ni que corresponda a ningún código fuente concreto, ni que
el proceso de build no estuviera comprometido. Para lo último hace falta
procedencia: una atestación que ligue el artefacto a la fuente y al builder,
que es lo que persiguen los niveles de SLSA.
</details>

**5. ¿Qué es la firma keyless y qué te da el registro de transparencia?**

<details><summary>Guía</summary>

En vez de una clave de larga vida, se obtiene un certificado efímero a partir de
una identidad OIDC —el token del workflow de GitHub Actions, por ejemplo— y se
firma con él. La firma se registra en Rekor, un log de transparencia
append-only. Ventaja: nada que rotar, nada que filtrar, y la identidad que firmó
es verificable (*este repo, esta rama, este workflow*), no solo "alguien con la
clave". El log permite además detectar firmas que no deberían existir.
</details>

**6. ¿Qué es un SBOM y por qué atestarlo es mejor que guardarlo como artefacto de
CI?**

<details><summary>Guía</summary>

Un inventario de componentes de la imagen. Como artefacto de CI vive en el
pipeline, caduca con la retención y no se puede consultar desde el cluster.
Atestado, viaja con la imagen en el registro, va firmado, y se puede verificar
desde donde corre. Cuando llega un CVE, la pregunta "¿qué imágenes en ejecución
contienen esta librería?" se responde consultando el registro, no arqueología en
los logs de CI.
</details>

## Escaneo

**7. Escaneas cada imagen en CI. Tres clases que no cubres.**

<details><summary>Guía</summary>

(a) Imágenes desplegadas antes de que el CVE se publicara: el escaneo pasó
porque en ese momento estaba limpia. (b) Imágenes que llegaron al cluster sin
pasar por CI — despliegues manuales, otro pipeline, un operador que trae las
suyas. (c) La imagen base fijada que escaneaste una vez; los CVE nuevos contra
ella aparecen después. Conclusión: escaneo continuo del registro **más** control
de admisión, no solo CI.
</details>

**8. Diferencia entre una vulnerabilidad presente y una alcanzable.**

<details><summary>Guía</summary>

Presente = el código vulnerable está en la imagen. Alcanzable = tu aplicación
realmente llama a esa ruta. La mayoría de hallazgos son presentes y no
alcanzables, de ahí la relación señal-ruido terrible de los escáneres genéricos
y de ahí que los equipos aprendan a ignorarlos. `govulncheck` para Go analiza el
grafo de llamadas y por eso es mucho más accionable que una comparación de
listas de paquetes.
</details>

## Runtime y secretos

**9. Un Secret de Kubernetes está en base64. ¿Qué protege?**

<details><summary>Guía</summary>

Nada. base64 es codificación, no cifrado — es reversible sin clave. Un Secret
protege en la medida en que lo hagan el RBAC y el cifrado en reposo de etcd, que
hay que habilitar explícitamente. Y `kubectl.kubernetes.io/last-applied-configuration`
puede dejar el valor en claro en una anotación del objeto. Para secretos de
verdad: un gestor externo, `sealed-secrets` o el operador del proveedor cloud.
</details>

**10. `readOnlyRootFilesystem: true` rompe tu aplicación. ¿Qué haces?**

<details><summary>Guía</summary>

Averiguar dónde escribe y darle un `emptyDir` montado solo ahí — normalmente
`/tmp`, un directorio de caché o un socket. Lo que **no** se hace es desactivar
la restricción. El beneficio: un atacante que consigue ejecución no puede dejar
un binario en el sistema de archivos, lo que corta la mayoría de las cadenas de
persistencia. Es de las medidas de endurecimiento con mejor relación
beneficio/coste, y suele costar un `emptyDir` de tres líneas.
</details>
