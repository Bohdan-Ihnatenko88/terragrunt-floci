variable "account_id" {
  description = "ID сервисного аккаунта (часть e-mail до @)"
  type        = string
}

variable "display_name" {
  type    = string
  default = null
}
