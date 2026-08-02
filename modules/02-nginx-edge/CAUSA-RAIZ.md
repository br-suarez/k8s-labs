# Causa raíz — Módulo 02

> Solo después de haber escrito tu diagnóstico.

## El fallo principal: clave de caché incompleta

```nginx
proxy_cache_key "$scheme$request_method$host$request_uri";
```

La clave contiene esquema, método, host y URI. **No contiene nada de la
identidad del usuario.** Las peticiones de dos tenants distintos a
`GET /api/checks` producen exactamente la misma clave.

El primero en pedir (cliente A) provoca un MISS: NGINX va al upstream, obtiene
los datos de A y los guarda. El siguiente que pida esa URI dentro de la ventana
de 5 segundos —sea quien sea— obtiene un HIT y recibe la respuesta de A.

La aplicación es correcta. NGINX es correcto. **La configuración es el bug**, y
por eso probar la API directamente no reproduce nada.

Los 5 segundos de `proxy_cache_valid` son lo que hace el síntoma intermitente:
la fuga solo ocurre si dos usuarios distintos piden dentro de la misma ventana.
Con poco tráfico casi nunca pasa; con mucho, constantemente. De ahí el "a veces".

## 2. La mitigación inmediata

```nginx
proxy_cache off;
```

Una línea, efecto inmediato, sin riesgo. Se pierde el rendimiento de la caché y
no se pierde nada más.

**Por qué esa y no arreglar la clave directamente:** durante un incidente de
fuga de datos, el objetivo es parar la fuga con el cambio de menor riesgo
posible. Cambiar `proxy_cache_key` es un arreglo, pero si te equivocas en la
nueva clave la fuga sigue y crees que la has resuelto. Apagar la caché no puede
fallar parcialmente.

Esa distinción —mitigar con el cambio más seguro, arreglar después con calma— es
la que se evalúa en una entrevista de SRE senior.

## 3. El arreglo correcto

Hay dos enfoques y **no** son equivalentes:

### Opción A — incluir la identidad en la clave

```nginx
proxy_cache_key "$scheme$request_method$host$request_uri$http_authorization";
```

Cachea por usuario. Funciona, pero:
- Multiplica las entradas de caché por el número de usuarios activos.
- Mete un token de autenticación en una clave que se escribe a disco en el
  nombre de archivo (hasheado, pero aun así).
- El ratio de aciertos se desploma: cada usuario tiene su propia caché de 5s.

### Opción B — no cachear respuestas autenticadas

```nginx
proxy_no_cache     $http_authorization;
proxy_cache_bypass $http_authorization;
```

`proxy_no_cache` impide **guardar** la respuesta. `proxy_cache_bypass` impide
**servir** desde caché. Necesitas las dos: sin la segunda, una entrada
envenenada que ya esté en la caché se sigue sirviendo.

### Cuál elegir

Para Pulse, la **B**. El contenido de `/api/checks` es específico por usuario y
cambia poco entre peticiones del mismo usuario, así que la caché compartida
aporta poco y el riesgo es alto. La A tiene sentido cuando hay un número pequeño
y acotado de identidades, o cuando la respuesta es cara de generar.

La respuesta madura en entrevista es que la caché de contenido autenticado
debería vivir en la aplicación, donde se conoce el modelo de permisos, y no en
un proxy que solo ve cabeceras HTTP.

## 4. El segundo problema: keepalive que no funciona

```nginx
upstream pulse_api {
    server 127.0.0.1:8080;
    keepalive 32;
}
```

`keepalive 32` mantiene un pool de conexiones al upstream. Pero por defecto
NGINX habla HTTP/1.0 con el upstream y le pasa `Connection: close`. El pool
existe y no se usa nunca.

Faltan estas dos directivas en el `location`:

```nginx
proxy_http_version 1.1;
proxy_set_header Connection "";
```

**Por qué todavía no ha explotado:** cada petición abre y cierra una conexión
TCP nueva. Con tráfico bajo es solo latencia extra. Bajo carga real, esos
sockets se acumulan en `TIME_WAIT` y acabas agotando los puertos efímeros del
sistema — lo que produce 502 intermitentes que parecen un problema del backend
y no lo son.

Cómo confirmarlo:
```bash
ss -tan state time-wait | wc -l
sysctl net.ipv4.ip_local_port_range
```

## 5. El control que lo habría evitado

Una prueba en CI que pida el mismo recurso con dos identidades distintas y
falle si la segunda respuesta contiene datos de la primera:

```bash
a=$(curl -s -H "Authorization: Bearer $TOKEN_A" "$BASE/api/checks")
b=$(curl -s -H "Authorization: Bearer $TOKEN_B" "$BASE/api/checks")
[ "$a" != "$b" ] || { echo "FAIL: identical responses for different tenants"; exit 1; }
```

Cuatro líneas. Habría fallado el primer día.

**La lección general:** cualquier caché delante de contenido autenticado necesita
una prueba de aislamiento entre tenants, y esa prueba tiene que correr contra la
pila completa —incluido el proxy— porque contra la aplicación sola pasa siempre.
