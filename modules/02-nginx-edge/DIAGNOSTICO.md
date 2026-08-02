# Diagnóstico — Módulo 02

**Tiempo: 40 min.** Sin documentación, sin buscar, sin autocompletado.

## Parte A — escribir (25 min)

Desde un archivo vacío, escribe un `nginx.conf` completo que:

1. Escuche en 80 y redirija todo a 443.
2. Termine TLS en 443 con un certificado local.
3. Enrute `/` a `127.0.0.1:3000` y `/api/` a `127.0.0.1:8080`.
4. Pase al upstream la IP real del cliente y el protocolo original.
5. Cachee las respuestas de `/api/results` durante 5 segundos, y **solo** esas.
6. Añada una cabecera que diga si la respuesta vino de caché.
7. Tenga timeouts explícitos hacia el upstream — no los que vengan por defecto.
8. Escriba un log de acceso que incluya el tiempo del upstream por separado del
   tiempo total de la petición.

El 4, el 7 y el 8 son los que separan. El resto lo escribe cualquiera que haya
copiado un config alguna vez.

## Parte B — razonar (15 min)

1. `proxy_pass http://backend/` y `proxy_pass http://backend` (sin la barra
   final) dentro de un `location /api/`. ¿Qué URI recibe el upstream en cada
   caso? Es la fuente número uno de 404 al configurar un proxy.

2. Un endpoint devuelve 502 de forma intermitente, un 2% de las peticiones. El
   upstream no registra ningún error. Da tres hipótesis y el campo del log de
   NGINX que descartaría cada una.

3. Tienes `$request_time` de 4.2s y `$upstream_response_time` de 0.05s en la
   misma petición. ¿Qué está pasando? ¿Optimizarías el backend?

## Criterio de aprobado

- Parte A: los 8 requisitos, y el config arranca (`nginx -t` pasa).
- Parte B: las tres correctas. La 3 es eliminatoria — si respondes que hay que
  optimizar el backend, no has aprobado, porque es exactamente el error que
  manda a un equipo a optimizar lo que no falla.

## Resultado

- **Aprobado** → labs 00, 03 y 04. Sáltate 01 y 02. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Nota

Este diagnóstico es más difícil de aprobar de lo que parece. NGINX es de esas
tecnologías que casi todo el mundo ha "usado" y muy poca gente ha configurado
desde cero. Si lo suspendes, no es señal de nada malo.
