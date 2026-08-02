# Preguntas de entrevista — Módulo 02

## Proxy y enrutado

**1. `proxy_pass http://backend/` con barra final y sin ella, dentro de
`location /api/`. ¿Qué recibe el upstream?**

<details><summary>Guía</summary>

Con barra: NGINX sustituye la parte que coincide con el `location`. Una petición
a `/api/checks` llega al upstream como `/checks`. Sin barra: la URI se pasa
completa, `/api/checks`. Es la causa número uno de 404 al montar un proxy, y la
respuesta correcta incluye decir que depende del `location`, no del `proxy_pass`
aislado.
</details>

**2. `$request_time` 4.2s, `$upstream_response_time` 0.05s. ¿Qué pasa?**

<details><summary>Guía</summary>

El backend respondió en 50 ms. Los otros 4.15s son cliente o red: un cliente
lento leyendo la respuesta, una subida grande, o congestión. Optimizar el
backend no cambiaría nada. Con `proxy_buffering on` NGINX ya liberó al upstream,
así que el backend ni siquiera está esperando. Si además hubiera varios valores
en `$upstream_response_time` separados por comas, significa que hubo reintentos
a más de un upstream.
</details>

**3. 502 intermitentes, el 2% de las peticiones, sin errores en el upstream. Tres
hipótesis y cómo las descartas.**

<details><summary>Guía</summary>

(a) Agotamiento de puertos efímeros por keepalive mal configurado — `ss -tan
state time-wait | wc -l`. (b) El upstream cierra conexiones idle antes que
NGINX, y NGINX reutiliza una conexión ya muerta — comparar
`keepalive_timeout` de ambos lados. (c) El upstream tiene un backlog lleno y
rechaza conexiones — `ss -tln` y la columna Send-Q. El campo clave en el log es
`$upstream_status`, que estará vacío si NGINX nunca llegó a hablar con el
backend, y eso ya descarta la mitad de las hipótesis.
</details>

## Caché

**4. ¿Diferencia entre `proxy_no_cache` y `proxy_cache_bypass`? ¿Por qué suelen
ir juntas?**

<details><summary>Guía</summary>

`proxy_no_cache` decide si la respuesta se **guarda**. `proxy_cache_bypass`
decide si se **sirve** desde caché. Solo con la primera, las entradas que ya
están envenenadas se siguen sirviendo; solo con la segunda, se siguen guardando
respuestas privadas. Casi siempre quieres ambas con la misma condición.
</details>

**5. ¿Qué debe contener una clave de caché para contenido autenticado, y por qué
la respuesta suele ser "no lo caches en el proxy"?**

<details><summary>Guía</summary>

Debe contener todo lo que hace la respuesta distinta: identidad, y cualquier
cabecera sobre la que varíe (`Accept-Encoding`, `Accept-Language`). El problema
es que el proxy no conoce el modelo de permisos: si mañana la aplicación empieza
a variar la respuesta por un campo nuevo, la clave se queda obsoleta en silencio
y vuelve la fuga. Por eso la caché de contenido autenticado pertenece a la
aplicación, y en el borde solo se cachea lo verdaderamente público.
</details>

**6. `proxy_cache_lock` — ¿qué problema resuelve?**

<details><summary>Guía</summary>

La estampida de caché: cuando una entrada popular expira, todas las peticiones
concurrentes fallan a la vez y van al upstream simultáneamente. `proxy_cache_lock
on` deja pasar solo una y hace esperar al resto. Complemento útil:
`proxy_cache_use_stale updating`, que sirve la entrada caducada mientras se
refresca — degradación elegante en vez de un pico de carga.
</details>

## Buffering y TLS

**7. `proxy_buffering on` vs `off`. Nombra un workload que se rompe con cada
uno.**

<details><summary>Guía</summary>

Con `on` (por defecto), NGINX lee la respuesta completa antes de mandarla al
cliente: protege al upstream de clientes lentos, pero rompe Server-Sent Events,
streaming y respuestas largas progresivas, que llegan de golpe al final. Con
`off`, el streaming funciona pero un cliente lento mantiene ocupado un worker del
backend todo el tiempo, que es justo el ataque Slowloris.
</details>

**8. Terminas TLS en NGINX. ¿Qué tiene que saber el backend y cómo se lo dices?**

<details><summary>Guía</summary>

Que la conexión original era HTTPS y cuál era la IP real del cliente:
`X-Forwarded-Proto $scheme`, `X-Forwarded-For`, `X-Real-IP`. Sin
`X-Forwarded-Proto`, una aplicación que genera URLs absolutas emitirá enlaces
`http://` y provocará bucles de redirección. Y hay que decir explícitamente en
qué proxies se confía (`set_real_ip_from`), porque si no, un cliente puede
falsificar `X-Forwarded-For`.
</details>

## Trade-offs

**9. Defiende NGINX frente a HAProxy y a Envoy para el borde de Pulse. Ahora
argumenta cuándo elegirías cada uno de los otros dos.**

<details><summary>Guía</summary>

NGINX: sirve estáticos y hace proxy en un solo proceso, config sencilla, huella
mínima — encaja porque Pulse necesita ambas cosas. HAProxy: mejor balanceo L4,
health checking más rico, mejores estadísticas; se elige cuando el balanceo es el
problema principal. Envoy: configuración dinámica por API, observabilidad nativa
(métricas y trazas sin trabajo extra), y es el plano de datos de la mayoría de
implementaciones de Gateway API — que es exactamente por lo que el módulo 05
sustituye a NGINX por algo respaldado por Envoy.
</details>
