variable "account_id" {
  description = "Service account ID (the part of the e-mail before @)"
  type        = string
}

variable "display_name" {
  type    = string
  default = null
}
