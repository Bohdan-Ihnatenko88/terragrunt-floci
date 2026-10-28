variable "env" {
  description = "Environment: dev, stage or prod. Added to resource names. Set in infra/<env>/env.hcl"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env must be dev, stage or prod."
  }
}

variable "project" {
  type    = string
  default = "floci-local"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "with_compute" {
  description = <<-EOT
    Whether to create the Cloud Run service and Cloud SQL instance. If floci runs with *_MOCK=true,
    only the control plane appears (visible in floci-ui and the API). Without mock floci tries to start
    real containers via the Docker socket.
  EOT
  type        = bool
  default     = true
}
