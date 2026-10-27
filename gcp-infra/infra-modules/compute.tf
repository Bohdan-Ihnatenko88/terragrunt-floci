# «Тяжёлые» сервисы — только чтобы потрогать их через Terraform и увидеть в floci-ui.
# Приложение от них не зависит. Выключить: terraform apply -var with_compute=false
#
# В mock-режиме floci (CLOUDRUN_MOCK / CLOUDSQL_MOCK = true) создаётся только control plane.
# Без mock floci сам поднимет nginx и Postgres как Docker-контейнеры.

resource "google_storage_bucket_object" "site_index" {
  count        = var.with_compute ? 1 : 0
  bucket       = google_storage_bucket.processed.name
  name         = "site/index.html"
  content      = "<h1>orders-lab status page (served by Cloud Run on floci)</h1>"
  content_type = "text/html"
}

resource "google_cloud_run_v2_service" "status_page" {
  count               = var.with_compute ? 1 : 0
  name                = "orders-status"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  labels              = local.labels

  template {
    service_account = google_service_account.worker.email
    timeout         = "30s"

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    volumes {
      name = "site"
      gcs {
        bucket    = google_storage_bucket.processed.name
        read_only = true
      }
    }

    containers {
      image = "nginx:latest"

      ports {
        container_port = 80
      }

      volume_mounts {
        name       = "site"
        mount_path = "/usr/share/nginx/html"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "128Mi"
        }
      }
    }
  }

  depends_on = [google_storage_bucket_object.site_index]
}

resource "google_sql_database_instance" "orders" {
  count               = var.with_compute ? 1 : 0
  name                = "orders-pg"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = false

  settings {
    tier = "db-custom-1-3840"
  }
}

resource "google_sql_database" "orders" {
  count    = var.with_compute ? 1 : 0
  name     = "orders"
  instance = google_sql_database_instance.orders[0].name
}

resource "google_sql_user" "app" {
  count    = var.with_compute ? 1 : 0
  name     = "app"
  instance = google_sql_database_instance.orders[0].name
  password = "local-only-password"
}
