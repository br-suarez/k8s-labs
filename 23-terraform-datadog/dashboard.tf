# The dashboard an on-call engineer opens when a burn-rate monitor pages.
#
# Ordered by the question being asked, not by data source:
#   1. Is there budget left?   (decide: ship, or stop and fix)
#   2. How fast is it going?   (decide: page-worthy, or ticket)
#   3. What do users see?      (RED)
#   4. Why?                    (saturation)
resource "datadog_dashboard" "service_slo" {
  title       = "${var.service} — SLO & Error Budget"
  layout_type = "ordered"
  description = "Managed by Terraform (23-terraform-datadog). UI edits are reverted on apply."

  # Makes the dashboard reusable across environments instead of copy-pasted per env.
  template_variable {
    name     = "env"
    prefix   = "env"
    defaults = [var.environment]
  }

  # Block is `service_level_objective_definition`, not `slo_definition`.
  # `terraform providers schema -json` is the authoritative answer to "what is
  # this block actually called" — faster and more reliable than the docs.
  widget {
    service_level_objective_definition {
      title             = "Availability SLO — error budget remaining"
      slo_id            = datadog_service_level_objective.availability.id
      time_windows      = ["30d", "7d"]
      view_type         = "detail"
      view_mode         = "overall"
      show_error_budget = true
    }
  }

  widget {
    service_level_objective_definition {
      title             = "Latency SLO — error budget remaining"
      slo_id            = datadog_service_level_objective.latency.id
      time_windows      = ["30d"]
      view_type         = "detail"
      view_mode         = "overall"
      show_error_budget = true
    }
  }

  widget {
    timeseries_definition {
      title = "Error ratio vs budget (${local.availability_error_budget * 100}%)"

      request {
        formula {
          formula_expression = "errors / total"
          alias              = "error ratio"
        }
        query {
          metric_query {
            name  = "errors"
            query = local.requests_errors
          }
        }
        query {
          metric_query {
            name  = "total"
            query = local.requests_total
          }
        }
        display_type = "line"
      }

      # The budget drawn on the same axes as the signal. A threshold that lives
      # only in the alert definition means nobody looking at the graph knows how
      # close to it they are.
      marker {
        display_type = "error dashed"
        value        = "y = ${local.availability_error_budget}"
        label        = "error budget (${local.availability_error_budget * 100}%)"
      }
      marker {
        display_type = "warning dashed"
        value        = "y = ${local.availability_error_budget * local.fast_burn_rate}"
        label        = "fast-burn page threshold"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Request rate by status"
      # Context for reading the ratio above: a 50% error rate computed from two
      # requests is noise, and every ratio panel needs a volume panel beside it.
      request {
        q            = "sum:trace.http.request.hits{service:${var.service},$env} by {http.status_code}.as_rate()"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Latency p50 / p95 / p99 vs ${var.latency_threshold_seconds}s objective"
      request {
        q            = "p50:trace.http.request{service:${var.service},$env}"
        display_type = "line"
      }
      request {
        q            = "p95:trace.http.request{service:${var.service},$env}"
        display_type = "line"
      }
      request {
        q            = "p99:trace.http.request{service:${var.service},$env}"
        display_type = "line"
      }
      marker {
        display_type = "error dashed"
        value        = "y = ${var.latency_threshold_seconds}"
        label        = "SLO threshold"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Saturation — CPU throttling and memory vs limit"
      # Throttling, not utilisation. A container pinned at its CPU limit may be
      # perfectly healthy; one being throttled is being starved, and that shows
      # up as latency long before any CPU graph looks wrong.
      request {
        q            = "avg:kubernetes.cpu.cfs.throttled.periods{service:${var.service},$env} / avg:kubernetes.cpu.cfs.periods{service:${var.service},$env}"
        display_type = "line"
      }
      request {
        q            = "avg:kubernetes.memory.working_set{service:${var.service},$env} / avg:kubernetes.memory.limits{service:${var.service},$env}"
        display_type = "line"
      }
    }
  }
}
