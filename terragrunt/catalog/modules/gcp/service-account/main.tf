# LEVEL 1 — MODULE.
# Plain Terraform: "how to create a service account". Knows nothing
# about Terragrunt or environments — all values come in through variables.

resource "google_service_account" "this" {
  account_id   = var.account_id
  display_name = var.display_name
}
