# The namespace is created here rather than inside the module: a module that
# creates its own namespace cannot be used twice in the same namespace, and
# deleting one instance would take the namespace (and anything else in it) with
# it. Ownership of shared containers belongs above the module.
resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

module "checkout" {
  source = "./modules/k8s-app"

  name        = "checkout"
  namespace   = kubernetes_namespace_v1.lab.metadata[0].name
  image       = "slo-demo:v1"
  replicas    = var.checkout_replicas
  app_version = "v1"

  config = {
    greeting      = "hello from terraform"
    feature_flags = "checkout_v2=off"
  }
}

# Imported later in the lab, NOT created by the first apply. It is written here
# up front so `terraform import` has a resource address to attach state to —
# import binds an existing object to an existing configuration block; it cannot
# generate the configuration for you (pre-1.5 workflows especially).
resource "kubernetes_config_map_v1" "legacy_settings" {
  metadata {
    name      = "legacy-settings"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    owner     = "payments-team"
    tier      = "internal"
    log_level = "info"
  }
}
