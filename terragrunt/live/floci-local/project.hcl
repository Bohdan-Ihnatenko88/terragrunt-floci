# Значения ОКРУЖЕНИЯ floci-local. Это единственное место, где лежат «цифры».
# Юниты из каталога находят этот файл сами через find_in_parent_folders("project.hcl").
# Для второго окружения (например floci-stage/) копируешь папку и меняешь только этот файл.

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

  # Читает юнит units/gcp/service-account
  service_account = {
    account_id   = "reporting-bot"
    display_name = "Reporting bot (terragrunt example)"
  }

  # Читает юнит units/gcp/pubsub
  pubsub = {
    topic = "reports"
    subscriptions = {
      reports-worker  = { ack_deadline_seconds = 60 }
      reports-archive = {}
    }
  }
}
