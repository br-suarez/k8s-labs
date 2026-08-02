# Triage runner: needs a shell, curl, jq, kubectl and python3.
#
FROM alpine:3.21

RUN apk add --no-cache bash curl jq python3 ca-certificates

# kubectl straight from dl.k8s.io, pinned.
#
# The first version of this file used `COPY --from=bitnami/kubectl:1.34.1`,
# which fails: Bitnami retired its public Docker Hub images, so that tag no
# longer resolves. Pulling the binary from the upstream Kubernetes release
# bucket has no such dependency on a third party's registry policy.
#
# Version matches the cluster (v1.34.0); kubectl supports +/-1 minor from the
# API server.
ARG KUBECTL_VERSION=v1.34.1
RUN curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl \
    && kubectl version --client=true --output=yaml | head -3

WORKDIR /app
COPY triage.sh receiver.py /app/
RUN chmod +x /app/triage.sh /app/receiver.py

# Reports are written here; mount a volume to keep them across restarts.
RUN mkdir -p /reports && adduser -D -u 1000 triage && chown triage /reports
USER triage

EXPOSE 9000
ENTRYPOINT ["python3", "/app/receiver.py"]
