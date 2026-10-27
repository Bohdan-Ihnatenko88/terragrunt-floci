# УРОВЕНЬ 1 — MODULE.
# Обычный Terraform: «как создать сервисный аккаунт». Ничего не знает
# ни про Terragrunt, ни про окружения — все значения приходят через variables.

resource "google_service_account" "this" {
  account_id   = var.account_id
  display_name = var.display_name
}
