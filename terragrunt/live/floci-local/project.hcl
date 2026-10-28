# Values for the floci-local ENVIRONMENT. This is the only place that holds concrete values.
# Catalog units find this file on their own via find_in_parent_folders("project.hcl").
# For a second environment (e.g. floci-stage/) copy the folder and change only this file.

locals {
  project = {
    id       = "floci-local"
    region   = "us-central1"
    endpoint = get_env("FLOCI_ENDPOINT", "http://localhost:4588")
    labels = {
      app        = "orders-lab"
      env        = "local"
      managed-by = "terragrunt"
    }
  }

  # Read by the units/gcp/service-account unit
  service_account = {
    account_id   = "reporting-bot"
    display_name = "Reporting bot (terragrunt example)"
  }

  # Read by the units/gcp/pubsub unit
  pubsub = {
    topic = "reports"
    subscriptions = {
      reports-worker  = { ack_deadline_seconds = 60 }
      reports-archive = {}
    }
  }
}
