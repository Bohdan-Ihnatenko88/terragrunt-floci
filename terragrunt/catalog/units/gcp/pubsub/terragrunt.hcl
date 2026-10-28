# LEVEL 2 — UNIT.
# The pubsub module + values from project.hcl + another unit's output (the service account e-mail).

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

# Dependency on a sibling unit in the same stack. Terragrunt applies
# service-account first, then this unit, and passes in its outputs.
# The default path is the sibling folder, but a stack can pass its own via values.
dependency "service_account" {
  config_path = try(values.service_account_path, "../service-account")

  # Until service-account has been applied at least once, plan/validate use this mock.
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
