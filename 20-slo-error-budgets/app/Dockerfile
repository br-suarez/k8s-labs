# Multi-stage build: the Go toolchain (~800 MB) never reaches the final image.
FROM golang:1.24-alpine AS build
WORKDIR /src
# go.mod and the source must both be present before `go mod tidy` runs:
# tidy prunes any requirement no source file imports, so tidying against a
# bare go.mod would silently drop client_golang and break the build below.
COPY src/go.mod src/main.go ./
RUN go mod tidy
# CGO_ENABLED=0 produces a fully static binary, which is what makes the
# scratch-based final stage possible: there is no libc in scratch to link against.
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /slo-demo .

FROM scratch
COPY --from=build /slo-demo /slo-demo
EXPOSE 8080
ENTRYPOINT ["/slo-demo"]
