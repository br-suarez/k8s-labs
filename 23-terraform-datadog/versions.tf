terraform {
  required_version = ">= 1.9"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.50"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = var.datadog_api_url

  # validate = false skips the provider's credential check against
  # /api/v1/validate at configure time.
  #
  # This is what makes `terraform plan` possible without a Datadog account: the
  # plan is computed entirely from the configuration, since every resource here
  # is a creation with no remote state to refresh. It is set from a variable so
  # a real environment leaves it at the default (true) and fails fast on bad
  # credentials instead of producing a plan it cannot apply.
  validate = var.datadog_validate
}
