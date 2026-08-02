variable "namespace" {
  description = "Namespace for the lab."
  type        = string
  default     = "tf-lab"
}

variable "checkout_replicas" {
  description = "Replica count for the checkout app."
  type        = number
  default     = 2
}
