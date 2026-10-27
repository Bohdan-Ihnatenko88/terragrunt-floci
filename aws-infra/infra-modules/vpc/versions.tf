terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68.0" # та же ветка, на которой гоняются compat-тесты floci-gcp
    }
  }
}
