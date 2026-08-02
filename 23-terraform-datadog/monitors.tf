# Burn-rate monitors attached to the SLO, not raw threshold alerts.
#
# Datadog's slo_burn_rate monitor type implements the multi-window logic
# natively: it requires BOTH a long and a short window to breach, which is the
# same design proven end to end in module 20 — the short window is what stops an
# alert from paging for another 8 minutes after the incident is already over.

resource "datadog_monitor" "availability_fast_burn" {
  name = "[${var.environment}] ${var.service} — availability error budget burning 14.4x"
  type = "slo alert"

  query = <<-EOT
    burn_rate("${datadog_service_level_objective.availability.id}").over("7d").long_window("1h").short_window("5m") > ${local.fast_burn_rate}
  EOT

  message = <<-EOT
    {{#is_alert}}
    ${var.service} is burning its availability error budget ${local.fast_burn_rate}x too fast.
    At this rate the entire budget is gone in under 2 days.

    Runbook: https://github.com/br-suarez/k8s-labs/blob/main/20-slo-error-budgets/README.md#runbook
    1. Confirm it is real — check request rate before trusting a ratio.
    2. Scope it — one host or all of them?
    3. Check remaining budget to choose rollback vs fix-forward.
    {{/is_alert}}

    {{#is_recovery}}
    Burn rate back within budget for ${var.service}.
    {{/is_recovery}}

    ${local.notify}
  EOT

  # Paging alert: renotify while unacknowledged.
  renotify_interval = 30
  # Do not alert when the SLO has no data — a service receiving no traffic has
  # not been proven healthy, but it has not failed either, and paging on absent
  # data trains people to ignore the alert.
  notify_no_data = false

  tags     = concat(local.common_tags, ["severity:critical", "burn_rate:14.4"])
  priority = 1
}

resource "datadog_monitor" "availability_slow_burn" {
  name = "[${var.environment}] ${var.service} — availability error budget burning 6x"
  type = "slo alert"

  query = <<-EOT
    burn_rate("${datadog_service_level_objective.availability.id}").over("7d").long_window("6h").short_window("30m") > ${local.slow_burn_rate}
  EOT

  message = <<-EOT
    {{#is_alert}}
    ${var.service} is burning its availability error budget ${local.slow_burn_rate}x too fast.
    Sustained, this exhausts the budget in under 5 days.
    {{/is_alert}}

    ${local.notify}
  EOT

  renotify_interval = 60
  notify_no_data    = false

  tags     = concat(local.common_tags, ["severity:critical", "burn_rate:6"])
  priority = 2
}

resource "datadog_monitor" "availability_budget_drain" {
  name = "[${var.environment}] ${var.service} — availability budget draining 3x (ticket)"
  type = "slo alert"

  query = <<-EOT
    burn_rate("${datadog_service_level_objective.availability.id}").over("30d").long_window("1d").short_window("2h") > ${local.ticket_burn}
  EOT

  message = <<-EOT
    {{#is_alert}}
    Chronic low-grade failure on ${var.service}. This does NOT warrant a page —
    create a ticket. At ${local.ticket_burn}x the budget is gone in ~10 days.
    {{/is_alert}}

    @slack-sre-tickets
  EOT

  # No renotify: a ticket-severity alert that nags is a page with extra steps.
  renotify_interval = 0
  notify_no_data    = false

  tags     = concat(local.common_tags, ["severity:warning", "burn_rate:3"])
  priority = 4
}

resource "datadog_monitor" "latency_fast_burn" {
  name = "[${var.environment}] ${var.service} — latency error budget burning 14.4x"
  type = "slo alert"

  query = <<-EOT
    burn_rate("${datadog_service_level_objective.latency.id}").over("7d").long_window("1h").short_window("5m") > ${local.fast_burn_rate}
  EOT

  message = <<-EOT
    {{#is_alert}}
    ${var.service} is serving too many requests slower than ${var.latency_threshold_seconds}s.
    Check saturation before assuming a code regression — CPU throttling produces
    exactly this shape.
    {{/is_alert}}

    ${local.notify}
  EOT

  renotify_interval = 30
  notify_no_data    = false

  tags     = concat(local.common_tags, ["severity:critical", "burn_rate:14.4", "slo:latency"])
  priority = 1
}
