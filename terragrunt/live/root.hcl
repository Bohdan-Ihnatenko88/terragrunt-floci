# Корневой конфиг: то, что общее для ВСЕХ юнитов во всех окружениях.
# Каждый юнит подключает его через include "root" { path = find_in_parent_folders("root.hcl") }.

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  project      = local.project_vars.locals.project
}

# provider.tf генерируется в каждый юнит — тот же провайдер, что в terraform/providers.tf,
# только значения берутся из project.hcl текущего окружения.
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

# State каждого юнита — отдельный файл. В настоящем проекте тут был бы GCS-бакет
# (backend = "gcs"), здесь для простоты — локальная папка live/.state/.
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
