# LEVEL 3 — STACK.
# Just a list of units deployed together: the "reporting pipeline" =
# a service account + a topic with subscriptions that this account is granted access to.
# No logic of its own. Units take their values from the environment's project.hcl.

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
