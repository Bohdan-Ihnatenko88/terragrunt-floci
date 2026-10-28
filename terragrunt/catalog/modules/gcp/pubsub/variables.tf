variable "topic" {
  type = string
}

variable "subscriptions" {
  description = "Subscriptions on the topic: name => settings"
  type = map(object({
    ack_deadline_seconds = optional(number, 30)
  }))
  default = {}
}

variable "subscribers" {
  description = "IAM members (serviceAccount:...) to grant roles/pubsub.subscriber"
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
