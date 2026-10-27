terraform {
  source = "../../../infra-modules"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  with_compute = true
}
