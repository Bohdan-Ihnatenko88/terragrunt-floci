# «Инфра-команда» проекта: всё, что в реальной жизни лежало бы в terraform-репо.
# Приложение (app/) эти ресурсы только использует.

locals {
  labels = { app = "orders-lab", env = "local" }
}

# ── Сервисный аккаунт приложения ─────────────────────────────────────────────
resource "google_service_account" "worker" {
  account_id   = "orders-worker"
  display_name = "Orders pipeline worker"
}

# ── Cloud Storage ────────────────────────────────────────────────────────────
# uploads   — сюда партнёры кладут CSV с заказами (incoming/...)
# processed — сюда воркер переносит обработанные файлы
resource "google_storage_bucket" "uploads" {
  name                        = "${var.project}-uploads"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = false
  labels                      = local.labels
}

resource "google_storage_bucket" "processed" {
  name                        = "${var.project}-processed"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = false
  labels                      = local.labels
}

resource "google_storage_bucket_object" "readme" {
  bucket       = google_storage_bucket.uploads.name
  name         = "README.txt"
  content      = "Кладите CSV с заказами в incoming/ — воркер подхватит их через Pub/Sub."
  content_type = "text/plain"
}

# ── Pub/Sub ──────────────────────────────────────────────────────────────────
# uploads          ← события GCS (OBJECT_FINALIZE), нотификацию вешает `lab.py bootstrap`
# report-requests  ← Cloud Scheduler раз в минуту
resource "google_pubsub_topic" "uploads" {
  name   = "uploads"
  labels = local.labels
}

resource "google_pubsub_subscription" "uploads_worker" {
  name                 = "uploads-worker"
  topic                = google_pubsub_topic.uploads.id
  ack_deadline_seconds = 60
}

resource "google_pubsub_topic" "report_requests" {
  name   = "report-requests"
  labels = local.labels
}

resource "google_pubsub_subscription" "report_worker" {
  name                 = "report-worker"
  topic                = google_pubsub_topic.report_requests.id
  ack_deadline_seconds = 30
}

resource "google_pubsub_subscription_iam_member" "worker_uploads" {
  subscription = google_pubsub_subscription.uploads_worker.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.worker.email}"
}

# ── Secret Manager ───────────────────────────────────────────────────────────
# «Ключ партнёрского API», которым воркер подписывает заказы (HMAC).
resource "google_secret_manager_secret" "partner_api_key" {
  secret_id = "partner-api-key"

  replication {
    auto {}
  }

  labels = local.labels
}

resource "google_secret_manager_secret_version" "partner_api_key_v1" {
  secret      = google_secret_manager_secret.partner_api_key.id
  secret_data = "pk_live_v1_do-not-commit-me"
}

resource "google_secret_manager_secret_iam_member" "worker_reads_key" {
  secret_id = google_secret_manager_secret.partner_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.worker.email}"
}

# ── Cloud KMS ────────────────────────────────────────────────────────────────
# Шифруем e-mail клиентов перед записью в Firestore (PII не лежит в открытом виде).
resource "google_kms_key_ring" "orders" {
  name     = "orders"
  location = var.region
}

resource "google_kms_crypto_key" "pii" {
  name     = "customer-pii"
  key_ring = google_kms_key_ring.orders.id
  purpose  = "ENCRYPT_DECRYPT"
}

# ── BigQuery ─────────────────────────────────────────────────────────────────
# Аналитика по заказам — без PII.
resource "google_bigquery_dataset" "orders" {
  dataset_id                 = "orders"
  friendly_name              = "Orders analytics"
  location                   = "US"
  delete_contents_on_destroy = true
  labels                     = local.labels
}

resource "google_bigquery_table" "orders" {
  dataset_id          = google_bigquery_dataset.orders.dataset_id
  table_id            = "orders"
  deletion_protection = false

  schema = jsonencode([
    { name = "order_id", type = "STRING", mode = "REQUIRED" },
    { name = "country", type = "STRING", mode = "NULLABLE" },
    { name = "status", type = "STRING", mode = "NULLABLE" },
    { name = "amount", type = "FLOAT", mode = "NULLABLE" },
    { name = "source_file", type = "STRING", mode = "NULLABLE" },
    { name = "processed_at", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}
