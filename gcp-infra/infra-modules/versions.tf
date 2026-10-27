# Provider "google" с адресами floci генерируется Terragrunt из gcp-infra/root.hcl.
# Запускать модуль нужно через terragrunt из infra/<env>/<unit>, а не terraform напрямую.
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.36" # та же ветка, на которой гоняются compat-тесты floci-gcp
    }
  }
}
