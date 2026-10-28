# floci-local ENVIRONMENT: which catalog stacks are deployed here.
# Counterpart of terragrunt-infrastructure/b2spin-dev/gcp/terragrunt.stack.hcl.

locals {
  catalog = "${dirname(find_in_parent_folders("root.hcl"))}/../catalog"
}

stack "reporting" {
  source = "${local.catalog}/stacks/gcp/reporting"
  path   = "reporting"
}
