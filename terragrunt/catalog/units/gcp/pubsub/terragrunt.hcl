# УРОВЕНЬ 2 — UNIT.
# Модуль pubsub + значения из project.hcl + выход другого юнита (e-mail сервисного аккаунта).

locals {
  catalog      = "${dirname(find_in_parent_folders("root.hcl"))}/../catalog"
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  project      = local.project_vars.locals.project
  pubsub       = local.project_vars.locals.pubsub
}

terraform {
  source = "${local.catalog}/modules/gcp/pubsub"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Зависимость от соседнего юнита в том же стеке. Terragrunt сначала применит
# service-account, а потом этот юнит, и подставит его outputs.
# Путь по умолчанию — «соседняя папка», но стек может передать свой через values.
dependency "service_account" {
  config_path = try(values.service_account_path, "../service-account")

  # Пока service-account ещё ни разу не применён, plan/validate используют заглушку.
  mock_outputs = {
    member = "serviceAccount:mock@floci-local.iam.gserviceaccount.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  topic         = local.pubsub.topic
  subscriptions = try(local.pubsub.subscriptions, {})
  labels        = local.project.labels
  subscribers   = [dependency.service_account.outputs.member]
}
