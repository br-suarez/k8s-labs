# Preguntas de entrevista — Módulo 16

No son sobre una tecnología. Son las que se hacen a un SRE senior, y las
respuestas salen de haber operado la plataforma, no de haberla leído.

## Incidentes

**1. Te paginan a las 3am. ¿Qué haces en los primeros cinco minutos?**

<details><summary>Guía</summary>

Confirmar el impacto en usuarios antes que la causa: ¿está caído, degradado, o
es una alerta ruidosa? Anunciar que lo estás mirando, para que nadie duplique el
trabajo. Y empezar a registrar comandos desde el primer minuto, porque la
cronología no se reconstruye después. **Mitigar antes que entender** es la parte
que más cuesta a la gente técnicamente fuerte: si puedes restaurar el servicio
sin saber la causa, hazlo y anota la hora.
</details>

**2. Cinco fallos simultáneos. ¿Cómo priorizas?**

<details><summary>Guía</summary>

Por impacto en usuarios primero, no por dificultad ni por orden de descubrimiento.
Y hay que reconocer el enmascaramiento: un Prometheus degradado hace que **todo**
parezca roto, así que arreglar la observabilidad primero suele ser lo correcto
aunque no sea lo que más duele. Una cosa cada vez: cambiar tres y ver que mejora
no te dice cuál era.
</details>

**3. Arreglas algo y otra cosa empeora. ¿Qué haces?**

<details><summary>Guía</summary>

Pararse y anotarlo — es una interacción, y probablemente el hallazgo más valioso
del incidente. Puede ser dependencia real (el segundo dependía del estado roto
del primero), presión de recursos redistribuida, o que el primer fallo estaba
enmascarando al segundo. Deshacer el arreglo si el neto empeoró, con la hora
registrada.
</details>

## Postmortems

**4. ¿Qué distingue un postmortem útil de uno que se archiva?**

<details><summary>Guía</summary>

La cronología con las **hipótesis fallidas**, no solo el camino que funcionó — el
camino limpio no enseña a nadie. Factores contribuyentes separados de la causa
raíz: normalmente hay más ahí, y son los accionables. Acciones con dueño y
criterio de terminado, no "mejorar la monitorización". Y una sección de qué salió
bien, porque lo que funcionó hay que preservarlo deliberadamente.
</details>

**5. ¿Qué es un postmortem sin culpa y por qué no es blandura?**

<details><summary>Guía</summary>

Parte de que la gente hace lo razonable con la información que tiene. Si alguien
desplegó algo malo, la pregunta no es por qué se equivocó sino por qué el sistema
lo permitió y por qué nada lo detectó. No es evitar responsabilidad: es asumir
que buscar culpables garantiza que la próxima vez nadie cuente lo que pasó de
verdad, y ahí sí pierdes la información.
</details>

## Fiabilidad

**6. ¿Cómo decides cuánta fiabilidad es suficiente?**

<details><summary>Guía</summary>

Del impacto en el usuario y del coste, no de la aspiración. Un SLO que se cumple
siempre con margen enorme no informa ninguna decisión y probablemente sea
demasiado laxo; uno que se incumple siempre o es irreal o el sistema es
insuficiente. El presupuesto de error convierte "¿desplegamos el viernes?" en
una pregunta con respuesta numérica. Y hay que poder decir qué cuesta el
siguiente nueve — si no, la conversación es opinión.
</details>

**7. Un simulacro consumió presupuesto de error real. ¿Está mal?**

<details><summary>Guía</summary>

No, y hay que contarlo. Un Game Day que no consume presupuesto probablemente no
probó nada — significa que inyectaste algo inocuo. El presupuesto existe
precisamente para gastarlo en aprender de forma controlada en vez de en
sorpresas. Lo que sí hay que hacer es planificarlo: no ejecutar un simulacro con
el presupuesto ya agotado por incidentes reales.
</details>

**8. ¿Qué es la ingeniería del caos y en qué se diferencia de un simulacro?**

<details><summary>Guía</summary>

Un simulacro te mide a **ti**: algo se rompe, reaccionas, entrenas diagnóstico.
Un experimento mide el **sistema**: defines un estado estable medible, enuncias
una hipótesis falsable, acotas el radio de impacto y la condición de aborto
**antes**, y ejecutas lo mínimo que podría refutarla. La diferencia práctica es
que un experimento se puede automatizar y repetir, así que las afirmaciones de
resiliencia siguen siendo ciertas mientras el sistema cambia. Un simulacro no
escala; un experimento sí.
</details>

## Arquitectura

**9. Presenta tu plataforma en cinco minutos.**

<details><summary>Qué se evalúa</summary>

Que empieces por el problema y el usuario, no por la tecnología. Que la
arquitectura sea una frase y un diagrama, no una lista de herramientas. Que
llegues rápido a los trade-offs. Y que menciones lo que está mal sin que te lo
pregunten — quien solo cuenta las virtudes de su propio diseño no lo ha revisado.
</details>

**10. ¿Qué está mal en tu plataforma?**

<details><summary>Qué se evalúa</summary>

Es la pregunta que más información da al entrevistador y la que más candidatos
esquivan. Una buena respuesta nombra debilidades concretas con su razón —un
único punto de fallo aceptado a conciencia, una dependencia sin alternativa, una
parte con poca cobertura de pruebas— y distingue entre lo que es deuda conocida y
lo que es una decisión consciente. "Nada" es la peor respuesta posible.
</details>

**11. ¿Qué harías distinto si empezaras de cero?**

<details><summary>Qué se evalúa</summary>

Que hayas reflexionado, no que te arrepientas de todo. Lo interesante es que
distingas decisiones que fueron correctas con la información de entonces de las
que fueron errores incluso entonces. Y que menciones algo que harías **igual**,
porque eso demuestra criterio y no solo autocrítica.
</details>
