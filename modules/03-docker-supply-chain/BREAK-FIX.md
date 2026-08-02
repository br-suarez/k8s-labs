# Break-fix — Módulo 03

## El escenario

`pulse-worker` funciona perfectamente en desarrollo. Se ha migrado la imagen a
distroless para reducir superficie de ataque, ha pasado CI, y se ha desplegado.

En producción, **todos** los checks contra URLs `https://` fallan. Los `http://`
funcionan sin problema.

Log del worker:

```json
{"time":"2026-07-30T09:12:03Z","level":"WARN","msg":"probe failed","check":"chk-001",
 "url":"https://example.com","status":0,
 "err":"Get \"https://example.com\": tls: failed to verify certificate: x509: certificate signed by unknown authority"}
{"time":"2026-07-30T09:12:03Z","level":"WARN","msg":"probe failed","check":"chk-002",
 "url":"https://api.github.com","status":0,
 "err":"Get \"https://api.github.com\": tls: failed to verify certificate: x509: certificate signed by unknown authority"}
```

El Dockerfile:

```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/pulse-worker .

FROM gcr.io/distroless/static-debian12:nonroot
USER nonroot
COPY --from=build /out/pulse-worker /app/pulse-worker
WORKDIR /app
ENTRYPOINT ["/app/pulse-worker"]
```

## Lo que ya se ha descartado

- No es la red: `http://` funciona y resuelve DNS.
- No es el certificado del destino: `curl https://example.com` desde el host va
  bien, y desde la imagen `golang:1.23` de build también.
- No es el reloj: la hora del contenedor es correcta.
- No es el código: el mismo binario, ejecutado en el host, funciona.

## Datos adicionales

El equipo intentó depurarlo y reporta esto:

```
$ docker run --rm -it pulse-worker:latest sh
docker: Error response from daemon: failed to create task for container:
failed to create shim task: OCI runtime create failed: exec: "sh":
executable file not found in $PATH

$ docker run --rm pulse-worker:latest --version
{"time":"...","level":"ERROR","msg":"cannot write state","err":"open /app/state.json: permission denied"}
```

Ese segundo error es **un problema distinto** que apareció al investigar el
primero. Los dos son reales y hay que arreglar ambos.

## Tu trabajo

1. Diagnostica por qué fallan las conexiones HTTPS. Explica por qué funcionaba
   en la imagen de build y no en la final.
2. Diagnostica el `permission denied`. No es el mismo bug.
3. Arregla los dos. La imagen final debe seguir sin shell.
4. El equipo no pudo depurar porque no hay shell en la imagen. ¿Cómo se depura
   un contenedor distroless? Da dos técnicas.
5. Escribe la prueba en CI que habría detectado el fallo de HTTPS antes del
   despliegue.

## Pistas escalonadas

<details><summary>Pista 1</summary>

`x509: certificate signed by unknown authority` no significa que el certificado
del servidor sea malo. Significa que *quien valida* no tiene con qué validarlo.
¿Qué necesita un cliente TLS para verificar una cadena, y dónde vive normalmente
en un sistema Linux?
</details>

<details><summary>Pista 2</summary>

Lee el nombre de la imagen base con atención: `distroless/static-debian12`. La
palabra `static` describe qué contiene. Compara el contenido de esa imagen con
`distroless/base-debian12`. ¿Qué archivo hay en una y no en la otra?
</details>

<details><summary>Pista 3 — para el punto 2</summary>

Mira el orden de las instrucciones: `USER nonroot` está **antes** de `COPY` y de
`WORKDIR`. ¿Con qué propietario se crea `/app`, y quién intenta escribir dentro
después?
</details>

<details><summary>Pista 4 — para el punto 4</summary>

`docker debug`, o `kubectl debug` con un contenedor efímero. En ambos casos
adjuntas un contenedor *con* herramientas al mismo namespace del que no las
tiene. También sirve `docker run --rm -v` montando el sistema de archivos de la
imagen en otra que sí tenga shell.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Distroless es la recomendación correcta y casi todo el mundo se estrella con esto
la primera vez. Es también un ejemplo perfecto de un fallo que **CI no detecta**:
la imagen se construye, arranca y responde a `/healthz`. Solo falla cuando
intenta hablar con el mundo exterior, que es algo que la mayoría de pipelines no
prueba.
