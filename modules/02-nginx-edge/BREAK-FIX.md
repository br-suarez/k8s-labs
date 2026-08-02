# Break-fix — Módulo 02

## El escenario

Pulse lleva tres semanas en producción detrás de NGINX. Esta mañana, soporte
escala esto:

> "Un cliente dice que al entrar en el dashboard ve los checks de **otra
> empresa**. Le pasa a veces, no siempre. Si recarga, a veces se arregla."

Es una fuga de datos entre clientes. Tienes que encontrarla ya.

Este es el bloque de caché del config, que lleva ahí desde el primer día:

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=pulse:10m
                 max_size=1g inactive=60m use_temp_path=off;

upstream pulse_api {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 443 ssl;
    server_name pulse.example.com;

    location /api/ {
        proxy_pass http://pulse_api/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;

        proxy_cache pulse;
        proxy_cache_valid 200 5s;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        add_header X-Cache-Status $upstream_cache_status;
    }

    location / {
        proxy_pass http://pulse_web;
    }
}
```

La API autentica con una cabecera `Authorization: Bearer <token>`, y cada tenant
ve solo sus propios checks. La aplicación es correcta: si le mandas dos tokens
distintos a `/api/checks`, devuelve datos distintos. Lo han verificado
llamándola directamente, saltándose NGINX.

## Datos adicionales

```
$ curl -sI -H 'Authorization: Bearer TOKEN_A' https://pulse.example.com/api/checks | grep -i x-cache
X-Cache-Status: MISS

$ curl -sI -H 'Authorization: Bearer TOKEN_B' https://pulse.example.com/api/checks | grep -i x-cache
X-Cache-Status: HIT
```

## Tu trabajo

1. Explica exactamente por qué el cliente B ve los datos del cliente A.
2. **Mitiga primero.** ¿Cuál es el cambio de una línea que corta la fuga ahora
   mismo, antes de arreglarlo bien? Justifica por qué ese y no otro.
3. Arréglalo correctamente. Hay más de una forma; elige una y defiéndela.
4. Hay un **segundo** problema latente en ese config que todavía no ha causado
   un incidente pero lo hará. Encuéntralo.
5. Escribe el control que impediría que esta clase de bug llegue a producción.

Anota el tiempo hasta el diagnóstico en `NOTAS.md`.

## Pistas escalonadas

<details><summary>Pista 1</summary>

Lee `proxy_cache_key` en voz alta, campo por campo, y pregúntate: dadas dos
peticiones de dos usuarios distintos a la misma URL, ¿producen claves distintas?
</details>

<details><summary>Pista 2</summary>

La caché no sabe nada de autenticación salvo que se lo digas. NGINX tiene dos
mecanismos distintos para esto y hacen cosas diferentes: uno cambia la clave,
otro decide si se cachea. Necesitas entender cuál resuelve qué.
</details>

<details><summary>Pista 3 — para el punto 4</summary>

Mira el `upstream` con `keepalive 32` y luego mira qué cabeceras le pasa
`location /api/` al upstream. Para que las conexiones keepalive funcionen de
verdad hacen falta dos directivas más que no están. Sin ellas, cada petición
abre una conexión nueva — y bajo carga eso agota los puertos efímeros.
</details>

Causa raíz en `CAUSA-RAIZ.md`. Escribe tu diagnóstico antes de abrirlo.

## Por qué este break-fix está aquí

El envenenamiento de caché por una clave incompleta es uno de los fallos de
producción más caros que existen, porque no rompe nada: todo sigue devolviendo
200 y la aplicación es correcta. El único síntoma es que alguien ve algo que no
debería, y eso puede tardar semanas en reportarse.
