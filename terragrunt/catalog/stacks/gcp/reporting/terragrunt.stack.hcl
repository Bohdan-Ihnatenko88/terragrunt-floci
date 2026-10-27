# УРОВЕНЬ 3 — STACK.
# Просто список юнитов, которые разворачиваются вместе: «отчётный пайплайн» =
# сервисный аккаунт + топик с подписками, на которые этому аккаунту выданы права.
# Своей логики тут нет. Значения юниты берут из project.hcl окружения.

locals {
  catalog = "${dirname(find_in_parent_folders("root.hcl"))}/../catalog"
}

unit "service-account" {
  source = "${local.catalog}/units/gcp/service-account"
  path   = "service-account"
}

unit "pubsub" {
  source = "${local.catalog}/units/gcp/pubsub"
  path   = "pubsub"
}
