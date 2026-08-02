# Causa raíz — Módulo 03

> Solo después de haber escrito tu diagnóstico.

## Bug 1 — faltan los certificados raíz

`gcr.io/distroless/static-debian12` contiene, literalmente, casi nada: sin shell,
sin libc, sin gestor de paquetes... y **sin `/etc/ssl/certs/ca-certificates.crt`**.

Cuando el binario de Go intenta una conexión TLS, busca el almacén de CAs del
sistema en las rutas habituales:

```
/etc/ssl/certs/ca-certificates.crt      (Debian/Ubuntu)
/etc/pki/tls/certs/ca-bundle.crt        (RHEL)
/etc/ssl/ca-bundle.pem                  (SUSE)
```

No encuentra ninguna. Sin CAs de confianza no puede verificar ninguna cadena, y
**todo** certificado —incluso uno perfectamente válido de Let's Encrypt— resulta
"signed by unknown authority".

**Por qué funcionaba en la imagen de build:** `golang:1.23` está basada en Debian
y trae `ca-certificates` instalado. El binario es idéntico; el entorno no.

Esa es la lección transferible: **el binario no lleva su entorno dentro**. Un
build estático elimina las dependencias de bibliotecas, no las de archivos de
datos.

### El arreglo

Dos opciones. La primera es la correcta:

```dockerfile
# Opción A — copiar los certificados desde la etapa de build
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
```

```dockerfile
# Opción B — usar una base que ya los traiga
FROM gcr.io/distroless/base-debian12:nonroot
```

La A mantiene la imagen mínima y es explícita sobre lo que se incluye y por qué.
La B es más simple pero arrastra libc y algo más de superficie.

Para `static-debian12` con un binario `CGO_ENABLED=0`, la **A**.

## Bug 2 — `USER` antes de `COPY`

```dockerfile
USER nonroot                                    # ← cambia el usuario
COPY --from=build /out/pulse-worker /app/...    # ← crea /app
WORKDIR /app
```

`COPY` crea `/app` con propietario **root**, independientemente del `USER`
activo: las capas de imagen se construyen con permisos de root salvo que se diga
lo contrario. Después el proceso corre como `nonroot` e intenta escribir
`/app/state.json` dentro de un directorio que no le pertenece.

`USER` afecta a quién *ejecuta*, no a quién *posee* lo que se copia.

### El arreglo

```dockerfile
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build --chown=nonroot:nonroot /out/pulse-worker /app/pulse-worker
WORKDIR /app
USER nonroot
ENTRYPOINT ["/app/pulse-worker"]
```

Dos cambios: `--chown` en el `COPY`, y `USER` al final por claridad.

**Mejor aún:** que la aplicación no escriba en su propio directorio. El estado va
a un volumen o a `/tmp`. Un sistema de archivos raíz de solo lectura es el
objetivo del módulo 12, y este bug desaparece por diseño.

## Depurar sin shell

```bash
# 1. Contenedor efímero adjunto al namespace del contenedor roto
kubectl debug -it pod/pulse-worker --image=busybox --target=pulse-worker

# 2. Inspeccionar el sistema de archivos de la imagen sin ejecutarla
docker create --name tmp pulse-worker:latest
docker export tmp | tar -tv | grep -E 'ssl|certs'
docker rm tmp

# 3. Montar el binario en una imagen que sí tenga herramientas
docker run --rm -it --entrypoint sh \
  -v $(docker create pulse-worker:latest):/broken alpine
```

La técnica 2 es la que resuelve este caso en treinta segundos: listas el
contenido de la imagen y ves que `/etc/ssl/` no existe.

## La prueba que lo habría detectado

El pipeline construía la imagen y comprobaba `/healthz`. Eso solo prueba que el
proceso arranca.

```bash
# smoke test: ejercitar una llamada saliente TLS real
docker run --rm --network host -d --name smoke pulse-worker:latest
sleep 3
curl -sf -XPOST localhost:8080/api/checks \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com","interval_seconds":1}'
sleep 20
fails=$(docker logs smoke 2>&1 | grep -c 'probe failed' || true)
docker rm -f smoke
[ "$fails" -eq 0 ] || { echo "FAIL: outbound TLS broken in image"; exit 1; }
```

**La lección general:** un smoke test que solo comprueba que el proceso arranca
valida la mitad menos interesante. La prueba tiene que ejercitar las
dependencias externas reales del servicio — red saliente, TLS, DNS, escritura en
disco — porque son exactamente las que cambian al cambiar la imagen base.
