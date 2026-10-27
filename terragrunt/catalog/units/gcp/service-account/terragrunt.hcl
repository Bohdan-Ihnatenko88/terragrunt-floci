# УРОВЕНЬ 2 — UNIT.
# Связывает модуль с окружением: какой модуль запускать и откуда брать для него значения.

locals {
  # Где лежит каталог. Юнит при запуске копируется внутрь live/<env>/.../.terragrunt-stack/,
  # поэтому путь считаем от root.hcl (в настоящем проекте здесь git::...?ref=master).
  catalog = "${dirname(find_in_parent_folders("root.hcl"))}/../catalog"

  # project.hcl ищется ВВЕРХ по папкам от места запуска → берётся файл нужного окружения.
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  sa           = local.project_vars.locals.service_account
}

# 1. Какой модуль запускать
terraform {
  source = "${local.catalog}/modules/gcp/service-account"
}

# 2. Общие настройки (provider, backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# 3. Значения для variables модуля
inputs = {
  account_id   = local.sa.account_id
  display_name = try(local.sa.display_name, local.sa.account_id)
}
