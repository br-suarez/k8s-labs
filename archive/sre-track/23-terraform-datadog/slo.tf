# The SLO as a first-class Datadog object.
#
# Defining it here rather than only as a monitor threshold means the error
# budget is computed by Datadog and visible to anyone — including people who
# will never open Terraform. It is also what the burn-rate monitors in
# monitors.tf attach to.
resource "datadog_service_level_objective" "availability" {
  name        = "${var.service} — availability"
  type        = "metric"
  description = <<-EOT
    Proportion of ${var.service} requests served without a server error.

    4xx responses count as SUCCESS: a malformed client request means the service
    behaved correctly. Counting them makes every vulnerability scan look like an
    outage.

    Managed by Terraform — edit 23-terraform-datadog/slo.tf, not the Datadog UI.
    UI edits will be reverted on the next apply.
  EOT

  query {
    numerator   = "${local.requests_total} - ${local.requests_errors}"
    denominator = local.requests_total
  }

  # Two windows on purpose. 30d is the contractual objective; 7d is the one an
  # on-call engineer can act on, because a 30-day window barely moves during an
  # incident.
  thresholds {
    timeframe = "30d"
    target    = var.availability_slo_target
    warning   = var.availability_slo_target + 0.3
  }

  thresholds {
    timeframe = "7d"
    target    = var.availability_slo_target
    warning   = var.availability_slo_target + 0.3
  }

  tags = local.common_tags
}

resource "datadog_service_level_objective" "latency" {
  name        = "${var.service} — latency"
  type        = "metric"
  description = <<-EOT
    Proportion of ${var.service} requests completing in under ${var.latency_threshold_seconds}s.

    A THRESHOLD RATIO, not a percentile. Percentiles cannot be averaged across
    hosts or re-windowed without producing a number that is confidently wrong;
    a ratio of counts can.
  EOT

  query {
    numerator   = "sum:trace.http.request.duration.by_type{service:${var.service},env:${var.environment}} - sum:trace.http.request.duration.by_type{service:${var.service},env:${var.environment},duration:above_${var.latency_threshold_seconds}s}"
    denominator = "sum:trace.http.request.duration.by_type{service:${var.service},env:${var.environment}}"
  }

  thresholds {
    timeframe = "30d"
    target    = var.latency_slo_target
    warning   = var.latency_slo_target + 0.5
  }

  tags = local.common_tags
}
