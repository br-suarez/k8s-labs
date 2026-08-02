terraform {
  required_version = ">= 1.9"

  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      # Pinned to a minor range. An unpinned provider means a `terraform init`
      # six months from now can produce a different plan from identical code,
      # which is the opposite of what state and code are supposed to guarantee.
      version = "~> 2.35"
    }
  }

  # Local backend on purpose: this lab has no cloud account, and the point being
  # practised (import, drift, refresh) behaves identically regardless of where
  # the state file lives. A real setup would use remote state with locking —
  # local state has no locking at all, so two concurrent applies corrupt it.
}

provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "kind-slo-lab"
}
