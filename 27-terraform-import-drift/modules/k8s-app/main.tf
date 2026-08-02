terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

locals {
  labels = {
    "app.kubernetes.io/name"       = var.name
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_config_map_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  data = var.config
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.name
      }
    }

    template {
      metadata {
        labels = local.labels
        annotations = {
          # Same trick as the Helm chart in module 26: without a hash of the
          # config in the pod template, changing a ConfigMap value updates the
          # object and never restarts the pods that read it.
          "checksum/config" = sha256(jsonencode(var.config))
        }
      }

      spec {
        container {
          name              = var.name
          image             = var.image
          image_pull_policy = "Never"

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name  = "APP_VERSION"
            value = var.app_version
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
            initial_delay_seconds = 1
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              memory = "64Mi"
            }
          }
        }
      }
    }
  }

  # Without this, `kubectl scale` drift is invisible: the provider would happily
  # leave replicas alone. It is commented out deliberately — see the README.
  # lifecycle {
  #   ignore_changes = [spec[0].replicas]
  # }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = var.name
    }

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
    }
  }
}
