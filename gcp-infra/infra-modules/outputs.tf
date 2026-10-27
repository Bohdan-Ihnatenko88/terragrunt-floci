output "uploads_bucket" {
  value = google_storage_bucket.uploads.name
}

output "processed_bucket" {
  value = google_storage_bucket.processed.name
}

output "worker_service_account" {
  value = google_service_account.worker.email
}

output "kms_key" {
  value = google_kms_crypto_key.pii.id
}

output "secret" {
  value = google_secret_manager_secret.partner_api_key.name
}

output "cloud_run_uri" {
  value = var.with_compute ? google_cloud_run_v2_service.status_page[0].uri : null
}

output "sql_instance" {
  value = var.with_compute ? google_sql_database_instance.orders[0].name : null
}
