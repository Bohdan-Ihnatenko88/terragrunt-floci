# Общие настройки для всех юнитов в infra/**.
# Всё, что касается floci, задаётся здесь. Переменные окружения не нужны.
locals {
  endpoint     = "http://localhost:4588" # адрес floci-gcp
  project      = "floci-local"           # проект по умолчанию у floci, его же показывает floci-ui
  region       = "us-central1"
  state_bucket = "${local.project}-tfstate"

  # Окружение берётся из infra/<env>/env.hcl. Сначала ищем рядом с terragrunt.hcl юнита
  # (find_in_parent_folders эту папку пропускает), потом выше по дереву.
  env_file = fileexists("${get_terragrunt_dir()}/env.hcl") ? "${get_terragrunt_dir()}/env.hcl" : find_in_parent_folders("env.hcl")
  env      = read_terragrunt_config(local.env_file).locals.env

  # Путь state внутри бакета: <env>/<юнит>/default.tfstate.
  # infra/dev → dev, infra/dev/network → dev/network
  state_prefix = trimprefix(path_relative_to_include(), "infra/")
}

# ── Provider: google, каждый API перенаправлен на floci ──────────────────────
# Список custom endpoints взят из floci-gcp/compatibility-tests/compat-terraform.
# Firestore/Datastore/Tasks/Scheduler через Terraform не заводим: для них у floci нет
# проверенного REST-пути под провайдер, их создаёт `python lab.py bootstrap`.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOT
provider "google" {
  project = "${local.project}"
  region  = "${local.region}"

  access_token          = "mock-token" # floci токен не проверяет
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

# ── Backend: state в GCS-бакете на floci ─────────────────────────────────────
# Блок remote_state не используем: при создании бакета Terragrunt игнорирует
# storage_custom_endpoint и идёт в настоящий storage.googleapis.com. Поэтому backend.tf
# генерируем сами, а бакет создаёт before_hook ниже.
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
  # Создаёт бакет для state перед init. Если бакет уже есть, floci вернёт 409, это норма.
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
          *) echo "Не удалось создать бакет ${local.state_bucket} (HTTP $code). floci запущен?" >&2; exit 1 ;;
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
