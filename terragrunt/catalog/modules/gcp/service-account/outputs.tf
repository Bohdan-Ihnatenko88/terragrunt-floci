output "email" {
  value = google_service_account.this.email
}

output "member" {
  description = "Ready-made member string for IAM bindings"
  value       = "serviceAccount:${google_service_account.this.email}"
}
