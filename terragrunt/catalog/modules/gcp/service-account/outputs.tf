output "email" {
  value = google_service_account.this.email
}

output "member" {
  description = "Готовая строка для IAM-привязок"
  value       = "serviceAccount:${google_service_account.this.email}"
}
