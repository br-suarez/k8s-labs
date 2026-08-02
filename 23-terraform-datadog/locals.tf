locals {
  # Error budget derived from the objective rather than written twice.
  # 99.5 -> 0.005
  availability_error_budget = (100 - var.availability_slo_target) / 100
  latency_error_budget      = (100 - var.latency_slo_target) / 100

  # Burn-rate thresholds, from the Google SRE Workbook multi-window table.
  # Expressed as multiples of the budget so changing the SLO target moves every
  # threshold with it. See ../20-slo-error-budgets/slo/slo-definition.md.
  fast_burn_rate = 14.4 # whole 30-day budget in ~2 days -> page
  slow_burn_rate = 6    # whole budget in ~5 days       -> page
  ticket_burn    = 3    # whole budget in ~10 days      -> ticket

  common_tags = [
    "service:${var.service}",
    "env:${var.environment}",
    "managed-by:terraform",
    "team:sre",
  ]

  # Base query fragments, defined once. A monitor and a dashboard widget that
  # disagree about what "error rate" means is how incidents turn into arguments
  # about which number is correct.
  requests_total  = "sum:trace.http.request.hits{service:${var.service},env:${var.environment}}.as_count()"
  requests_errors = "sum:trace.http.request.errors{service:${var.service},env:${var.environment}}.as_count()"

  notify = join(" ", var.notify_handles)
}
