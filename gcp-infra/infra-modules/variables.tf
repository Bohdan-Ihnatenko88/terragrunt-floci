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
