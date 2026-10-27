variable "env" {
  description = "Окружение: dev, stage или prod. Добавляется в имена ресурсов. Задаётся в infra/<env>/env.hcl"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env должен быть dev, stage или prod."
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
    Создавать ли Cloud Run сервис и Cloud SQL инстанс. Если floci запущен с *_MOCK=true —
    появится только control plane (видно в floci-ui и API). Без mock floci попытается поднять
    реальные контейнеры через Docker socket.
  EOT
  type        = bool
  default     = true
}
