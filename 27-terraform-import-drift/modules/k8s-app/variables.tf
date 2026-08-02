variable "name" {
  description = "Base name for every object the module creates."
  type        = string
}

variable "namespace" {
  description = "Namespace to deploy into. Must already exist."
  type        = string
}

variable "image" {
  description = "Container image, including tag."
  type        = string
}

variable "replicas" {
  description = "Desired replica count."
  type        = number
  default     = 2

  # Validation belongs in the module, not in the caller's head. Without it a
  # typo like replicas = -1 fails at apply time with an API error instead of at
  # plan time with a readable message.
  validation {
    condition     = var.replicas >= 1 && var.replicas <= 10
    error_message = "replicas must be between 1 and 10."
  }
}

variable "app_version" {
  description = "Value passed to the container as APP_VERSION."
  type        = string
  default     = "v1"
}

variable "config" {
  description = "Key/value pairs rendered into the ConfigMap."
  type        = map(string)
  default     = {}
}
