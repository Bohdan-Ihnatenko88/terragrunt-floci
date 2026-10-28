# The project's "infra team" part: everything that in real life would live in a terraform repo.
# The app (app/) only uses these resources.

locals {
  labels = { app = "orders-lab", env = var.env }
}

# ── App service account ──────────────────────────────────────────────────────
resource "google_service_account" "worker" {
  account_id   = "${var.env}-orders-worker"
  display_name = "Orders pipeline worker (${var.env})"
}

# ── Cloud Storage ────────────────────────────────────────────────────────────
# uploads   — partners drop order CSVs here (incoming/...)
# processed — the worker moves processed files here
resource "google_storage_bucket" "uploads" {
  name                        = "${var.project}-${var.env}-uploads"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = false
  labels                      = local.labels
}

resource "google_storage_bucket" "processed" {
  name                        = "${var.project}-${var.env}-processed"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = false
  labels                      = local.labels
}

resource "google_storage_bucket_object" "readme" {
  bucket       = google_storage_bucket.uploads.name
  name         = "README.txt"
  content      = "Put order CSVs into incoming/ — the worker picks them up via Pub/Sub."
  content_type = "text/plain"
}

# ── Pub/Sub ──────────────────────────────────────────────────────────────────
# uploads          ← GCS events (OBJECT_FINALIZE), the notification is set up by `lab.py bootstrap`
# report-requests  ← Cloud Scheduler once a minute
resource "google_pubsub_topic" "uploads" {
  name   = "${var.env}-uploads"
  labels = local.labels
}

resource "google_pubsub_subscription" "uploads_worker" {
  name                 = "${var.env}-uploads-worker"
  topic                = google_pubsub_topic.uploads.id
  ack_deadline_seconds = 60
}

resource "google_pubsub_topic" "report_requests" {
  name   = "${var.env}-report-requests"
  labels = local.labels
}

resource "google_pubsub_subscription" "report_worker" {
  name                 = "${var.env}-report-worker"
  topic                = google_pubsub_topic.report_requests.id
  ack_deadline_seconds = 30
}

resource "google_pubsub_subscription_iam_member" "worker_uploads" {
  subscription = google_pubsub_subscription.uploads_worker.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.worker.email}"
}

# ── Secret Manager ───────────────────────────────────────────────────────────
# "Partner API key" the worker uses to sign orders (HMAC).
resource "google_secret_manager_secret" "partner_api_key" {
  secret_id = "${var.env}-partner-api-key"

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
# Encrypt customer e-mails before writing to Firestore (no plaintext PII).
resource "google_kms_key_ring" "orders" {
  name     = "${var.env}-orders"
  location = var.region
}

resource "google_kms_crypto_key" "pii" {
  name     = "customer-pii"
  key_ring = google_kms_key_ring.orders.id
  purpose  = "ENCRYPT_DECRYPT"
}

# ── BigQuery ─────────────────────────────────────────────────────────────────
# Order analytics — no PII.
resource "google_bigquery_dataset" "orders" {
  dataset_id                 = "${var.env}_orders" # BigQuery allows only letters, digits and _
  friendly_name              = "Orders analytics (${var.env})"
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
