# Preguntas de entrevista — Módulo 10

## El modelo

**1. Argo dice `Synced` y `Healthy`. ¿Qué garantiza y qué no?**

<details><summary>Guía</summary>

`Synced` garantiza que los manifiestos renderizados desde Git coinciden con los
objetos del cluster **según las reglas de comparación configuradas** — y ahí está
la trampa: `ignoreDifferences` puede ocultar diferencias reales. `Healthy` es una
evaluación por tipo de recurso: para un Deployment, condiciones y réplicas
disponibles. Ninguno de los dos dice nada sobre si la aplicación **funciona**: un
Deployment con todos los pods corriendo y devolviendo 500 a todo es
`Synced` y `Healthy`. Por eso la salud real vive en el SLO del módulo 07, no en
el panel de Argo.
</details>

**2. Una Application nunca alcanza `Synced` y el YAML parece idéntico. Tres
causas.**

<details><summary>Guía</summary>

(a) Un webhook de admisión mutante añade campos tras aplicar — sidecars de mesh,
anotaciones, `securityContext` por defecto. (b) El API server rellena valores por
defecto que no están en tu manifiesto. (c) Otro controlador gestiona un campo:
un HPA moviendo `replicas` es el caso clásico. Los tres se resuelven con
`ignoreDifferences` **acotado a ese campo concreto**, que es su uso legítimo.
Diagnóstico: `argocd app diff`.
</details>

**3. ¿Qué hace exactamente `ignoreDifferences`? ¿Y qué NO hace?**

<details><summary>Guía</summary>

Afecta al **cálculo del diff**, no a la aplicación. Argo deja de reportar la
diferencia, pero `selfHeal` sigue aplicando el manifiesto completo de Git,
incluido ese campo. Es decir: puedes tener un panel en verde mientras el
controlador revierte activamente un cambio manual. Es el fallo del break-fix de
este módulo y una de las confusiones más comunes con Argo CD.
</details>

## Operación

**4. Son las 3am, hay una caída, parcheas a mano. ¿Qué pasa?**

<details><summary>Guía</summary>

Con `selfHeal: true`, tu cambio dura hasta la siguiente reconciliación —180s por
defecto— y desaparece. El procedimiento correcto: desactivar self-heal **solo en
esa Application**, aplicar el arreglo, anunciarlo, abrir el PR con el mismo
cambio antes de cerrar el incidente, y reactivar. Escalar el controlador a cero
funciona y es la peor opción: quita el gobierno de todo el cluster y alguien
tiene que acordarse de revertirlo.
</details>

**5. Un equipo se salta GitOps a mano tres veces por semana. ¿Problema de
disciplina?**

<details><summary>Guía</summary>

Casi nunca. Es la señal de que el camino normal es demasiado lento o demasiado
rígido: un pipeline de 25 minutos para un cambio de una línea, o revisión
obligatoria sin vía rápida para incidentes. La respuesta no es más proceso, es
arreglar la latencia del camino bueno. Un proceso que la gente evita
sistemáticamente está mal diseñado, no mal cumplido.
</details>

**6. Sync waves vs dependencias. ¿Cuándo hacen falta?**

<details><summary>Guía</summary>

Kubernetes no tiene ordenación declarativa entre recursos: aplicas todo y cada
controlador converge. Normalmente basta, porque los objetos reintentan. Las sync
waves (`argocd.argoproj.io/sync-wave`) imponen orden cuando la convergencia por
reintento no sirve: CRDs antes que los recursos que los usan, una migración de
base de datos antes del Deployment que la necesita, un namespace antes de su
contenido. Los sync hooks (`PreSync`, `PostSync`) cubren el caso de un Job que
debe completarse antes de continuar.
</details>

## Estructura

**7. Kustomize: ¿cómo evitas duplicar YAML entre entornos, y cuándo se rompe el
modelo?**

<details><summary>Guía</summary>

Una base con lo común y overlays que aplican patches estratégicos. Se rompe
cuando los entornos divergen tanto que el overlay es más grande que la base —
señal de que no son el mismo servicio con distinta configuración, sino dos
servicios. También sufre con lógica condicional, que Kustomize deliberadamente no
tiene: si necesitas condicionales, quieres Helm, y esa es la línea divisoria
honesta entre los dos.
</details>

**8. App-of-apps: qué es y qué problema crea.**

<details><summary>Guía</summary>

Una Application que despliega otras Applications, así que el bootstrap del
cluster entero es un solo objeto. Ventaja: un cluster nuevo se reconstruye
aplicando un manifiesto. Problema: un fallo en la app raíz afecta a todo, y el
borrado en cascada con `prune: true` puede llevarse aplicaciones enteras si
alguien edita mal la raíz. Por eso la app raíz se protege con
`prune: false` o con finalizers, y se revisa distinto que las hojas.
</details>

## Trade-offs

**9. Argo CD vs Flux vs `kubectl apply` desde CI. Un argumento para cada uno.**

<details><summary>Guía</summary>

Argo CD: interfaz visual que hace el drift evidente y baja mucho la barrera para
equipos de aplicación; multi-cluster y RBAC maduros. Flux: más ligero, más
componible, sin UI que mantener, mejor si todo tu flujo es CLI y GitOps puro.
`kubectl apply` desde CI: cero componentes nuevos, familiar — y pierdes la
detección de drift, que es la mitad del valor. Lo que ninguno de los dos
primeros te da gratis es saber si la aplicación *funciona*: eso sigue siendo tu
SLO.
</details>

**10. ¿Qué es lo que GitOps NO resuelve?**

<details><summary>Guía</summary>

No resuelve secretos —hace falta sealed-secrets, un operador externo o un gestor
de secretos—; no resuelve migraciones de datos, que no son declarativas; no
resuelve la latencia del despliegue, que sigue dependiendo de tu pipeline; y no
te dice si el cambio era correcto, solo que se aplicó. Y añade un modo de fallo
nuevo: el controlador puede revertir un arreglo legítimo, que es exactamente el
break-fix de este módulo.
</details>
