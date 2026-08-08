# Preguntas de entrevista — Módulo 08c

Sobre cómo se trabaja un incidente, no sobre una tecnología concreta.

**1. Te paginan y el servicio está caído. ¿Mitigas o diagnosticas primero?**

<details><summary>Guía</summary>

Mitigas. Si puedes restaurar el servicio sin conocer la causa —revertir el
despliegue, escalar, quitar un nodo del balanceo— hazlo y anota la hora. El
entendimiento viene después, con el servicio en pie y sin presión. Es el hábito
que más cuesta a los ingenieros técnicamente fuertes, porque el instinto es
entender antes de tocar, y en producción ese instinto cuesta minutos de caída.
</details>

**2. ¿Por qué registrar cada comando durante un incidente?**

<details><summary>Guía</summary>

Porque la cronología no se reconstruye después: a las dos horas recuerdas la
versión ordenada, no la real, y los callejones sin salida —que son la parte útil
del postmortem— se pierden los primeros. Además evita repetir comprobaciones ya
hechas cuando entra alguien nuevo al incidente, y permite responder "¿qué se ha
tocado?" sin adivinar.
</details>

**3. ¿Qué es una hipótesis y por qué escribirla antes de ejecutar el comando?**

<details><summary>Guía</summary>

Una afirmación comprobable sobre qué está fallando, con una predicción de lo que
verías si fuese cierta. Escribirla antes convierte tantear en diagnosticar: un
comando que no descarta nada no deberías haberlo ejecutado. Y hace explícito
cuándo una hipótesis muere, que es cuando la gente se queda atascada persiguiendo
la primera idea.
</details>

**4. Todos los indicadores en verde y el servicio falla. ¿Por dónde empiezas?**

<details><summary>Guía</summary>

Por lo que ve el usuario, hacia dentro. Si `kubectl get pods` dice que todo está
bien, el problema está en una capa que ese comando no mira: enrutado, endpoints,
readiness que miente, o algo por debajo de la aplicación. La lección del módulo
04 aplica: los indicadores verdes describen lo que miden, no la salud del
servicio.
</details>

**5. ¿Cuándo dejas de investigar y escalas?**

<details><summary>Guía</summary>

Cuando llevas un tiempo acordado sin progreso medible —45 minutos es un umbral
razonable—, cuando el impacto crece mientras investigas, o cuando necesitas
permisos o conocimiento que no tienes. Escalar pronto no es debilidad; la señal
de alarma es la conversación de "no quería molestar" en un postmortem.
</details>

**6. ¿Qué hace que un Game Day valga la pena?**

<details><summary>Guía</summary>

Que cambie el sistema después. Si no salen acciones concretas —una comprobación
nueva, una alerta que faltaba, un runbook— fue entretenimiento. El criterio
concreto: si el harness no detectó algo que tú acabaste encontrando a mano,
debería poder la próxima vez, y eso se verifica volviendo a inyectar el mismo
fallo.
</details>
