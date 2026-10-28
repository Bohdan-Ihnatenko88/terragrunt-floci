# LEVEL 2 — UNIT.
# Binds a module to an environment: which module to run and where to take its values from.

locals {
  # Where the catalog lives. At run time the unit is copied into live/<env>/.../.terragrunt-stack/,
  # so the path is computed from root.hcl (in a real project this would be git::...?ref=master).
  catalog = "${dirname(find_in_parent_folders("root.hcl"))}/../catalog"

  # project.hcl is searched UP the folders from where it runs → picks the right environment's file.
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  sa           = local.project_vars.locals.service_account
}

# 1. Which module to run
terraform {
  source = "${local.catalog}/modules/gcp/service-account"
}

# 2. Shared settings (provider, backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# 3. Values for the module's variables
inputs = {
  account_id   = local.sa.account_id
  display_name = try(local.sa.display_name, local.sa.account_id)
}
