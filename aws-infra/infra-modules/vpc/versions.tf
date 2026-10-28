terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68.0" # same branch the floci-gcp compat tests run on
    }
  }
}
