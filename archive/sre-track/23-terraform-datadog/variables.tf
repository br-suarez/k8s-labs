variable "datadog_api_key" {
  description = "Datadog API key. Supplied via TF_VAR_datadog_api_key, never committed."
  type        = string
  sensitive   = true
  default     = "PLAN_ONLY_PLACEHOLDER"
}

variable "datadog_app_key" {
  description = "Datadog application key. Supplied via TF_VAR_datadog_app_key."
  type        = string
  sensitive   = true
  default     = "PLAN_ONLY_PLACEHOLDER"
}

variable "datadog_api_url" {
  description = "Datadog site API URL. EU accounts must override this."
  type        = string
  default     = "https://api.datadoghq.com/"
}

variable "datadog_validate" {
  description = "Whether the provider validates credentials at configure time. false enables offline planning."
  type        = bool
  default     = true
}

variable "service" {
  description = "Service these monitors and SLOs describe."
  type        = string
  default     = "checkout-api"
}

variable "environment" {
  description = "Environment tag applied to every resource."
  type        = string
  default     = "production"
}

variable "notify_handles" {
  description = "Datadog notification targets appended to monitor messages."
  type        = list(string)
  default     = ["@slack-sre-alerts", "@pagerduty-sre"]
}

# Same numbers as module 20's SLO spec. Defined once here and referenced by the
# SLO, both burn-rate monitors and the dashboard, so the threshold cannot drift
# between the thing that pages and the thing people look at.
variable "availability_slo_target" {
  description = "Availability objective as a percentage."
  type        = number
  default     = 99.5

  validation {
    condition     = var.availability_slo_target > 0 && var.availability_slo_target < 100
    error_message = "availability_slo_target must be a percentage between 0 and 100."
  }
}

variable "latency_slo_target" {
  description = "Percentage of requests that must complete under latency_threshold_seconds."
  type        = number
  default     = 99.0
}

variable "latency_threshold_seconds" {
  description = "Latency objective in seconds."
  type        = number
  default     = 0.3
}
