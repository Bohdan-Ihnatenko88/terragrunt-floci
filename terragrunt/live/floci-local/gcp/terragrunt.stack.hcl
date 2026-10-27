# ОКРУЖЕНИЕ floci-local: какие стеки из каталога здесь развёрнуты.
# Аналог terragrunt-infrastructure/b2spin-dev/gcp/terragrunt.stack.hcl.

locals {
  catalog = "${dirname(find_in_parent_folders("root.hcl"))}/../catalog"
}

stack "reporting" {
  source = "${local.catalog}/stacks/gcp/reporting"
  path   = "reporting"
}
