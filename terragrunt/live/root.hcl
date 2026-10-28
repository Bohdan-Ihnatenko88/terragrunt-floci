# Root config: what is shared by ALL units in all environments.
# Each unit includes it via include "root" { path = find_in_parent_folders("root.hcl") }.

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  project      = local.project_vars.locals.project
}

# provider.tf is generated into every unit — the same provider as in terraform/providers.tf,
# except the values come from the current environment's project.hcl.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    terraform {
      required_version = ">= 1.6"
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 7.36"
        }
      }
    }

    provider "google" {
      project               = "${local.project.id}"
      region                = "${local.project.region}"
      access_token          = "mock-token"
      user_project_override = false

      storage_custom_endpoint          = "${local.project.endpoint}/storage/v1/"
      iam_custom_endpoint              = "${local.project.endpoint}/"
      iam_beta_custom_endpoint         = "${local.project.endpoint}/v1/"
      pubsub_custom_endpoint           = "${local.project.endpoint}/v1/"
      resource_manager_custom_endpoint = "${local.project.endpoint}/v1/"
    }
  EOT
}

# Each unit's state is a separate file. A real project would use a GCS bucket here
# (backend = "gcs"); for simplicity this uses the local folder live/.state/.
remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/.state/${path_relative_to_include()}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
