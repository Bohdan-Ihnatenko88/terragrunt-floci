# Shared settings for all units under infra/**.
# Everything floci-related is set here. No environment variables are needed.
locals {
  endpoint     = "http://localhost:4588" # floci-gcp address
  project      = "floci-local"           # floci's default project, also shown in floci-ui
  region       = "us-central1"
  state_bucket = "${local.project}-tfstate"

  # The environment comes from infra/<env>/env.hcl. Look next to the unit's terragrunt.hcl first
  # (find_in_parent_folders skips that folder), then further up the tree.
  env_file = fileexists("${get_terragrunt_dir()}/env.hcl") ? "${get_terragrunt_dir()}/env.hcl" : find_in_parent_folders("env.hcl")
  env      = read_terragrunt_config(local.env_file).locals.env

  # State path inside the bucket: <env>/<unit>/default.tfstate.
  # infra/dev → dev, infra/dev/network → dev/network
  state_prefix = trimprefix(path_relative_to_include(), "infra/")
}

# ── Provider: google, every API redirected to floci ─────────────────────────
# The custom endpoints list is taken from floci-gcp/compatibility-tests/compat-terraform.
# Firestore/Datastore/Tasks/Scheduler are not managed by Terraform: floci has no
# tested REST path for them in the provider, `python lab.py bootstrap` creates them.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOT
provider "google" {
  project = "${local.project}"
  region  = "${local.region}"

  access_token          = "mock-token" # floci does not validate the token
  user_project_override = false

  storage_custom_endpoint          = "${local.endpoint}/storage/v1/"
  iam_custom_endpoint              = "${local.endpoint}/"
  iam_beta_custom_endpoint         = "${local.endpoint}/v1/"
  secret_manager_custom_endpoint   = "${local.endpoint}/v1/"
  kms_custom_endpoint              = "${local.endpoint}/v1/"
  pubsub_custom_endpoint           = "${local.endpoint}/v1/"
  big_query_custom_endpoint        = "${local.endpoint}/bigquery/v2/"
  cloud_run_custom_endpoint        = "${local.endpoint}/v2/"
  cloud_run_v2_custom_endpoint     = "${local.endpoint}/v2/"
  sql_custom_endpoint              = "${local.endpoint}/sql/v1beta4/"
  service_usage_custom_endpoint    = "${local.endpoint}/v1/"
  resource_manager_custom_endpoint = "${local.endpoint}/v1/"
}
EOT
}

# ── Backend: state in a GCS bucket on floci ──────────────────────────────────
# remote_state is not used: when creating the bucket Terragrunt ignores
# storage_custom_endpoint and calls the real storage.googleapis.com. So backend.tf
# is generated here and the before_hook below creates the bucket.
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOT
terraform {
  backend "gcs" {
    bucket                  = "${local.state_bucket}"
    prefix                  = "${local.state_prefix}"
    storage_custom_endpoint = "${local.endpoint}/storage/v1/"
    access_token            = "mock-token"
  }
}
EOT
}

terraform {
  # Creates the state bucket before init. If it already exists floci returns 409, which is fine.
  before_hook "ensure_state_bucket" {
    commands = ["init"]
    execute = [
      "sh", "-c",
      <<-EOT
        code=$(curl -s -o /dev/null -w '%%{http_code}' -X POST \
          -H 'Content-Type: application/json' \
          -d '{"name":"${local.state_bucket}","versioning":{"enabled":true}}' \
          '${local.endpoint}/storage/v1/b?project=${local.project}')
        case "$code" in
          200|409) ;;
          *) echo "Failed to create bucket ${local.state_bucket} (HTTP $code). Is floci running?" >&2; exit 1 ;;
        esac
      EOT
    ]
  }
}

inputs = {
  env     = local.env
  project = local.project
  region  = local.region
}
