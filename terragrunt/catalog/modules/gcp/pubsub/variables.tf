variable "topic" {
  type = string
}

variable "subscriptions" {
  description = "Подписки на топик: имя => настройки"
  type = map(object({
    ack_deadline_seconds = optional(number, 30)
  }))
  default = {}
}

variable "subscribers" {
  description = "IAM-участники (serviceAccount:...), которым выдать roles/pubsub.subscriber"
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
