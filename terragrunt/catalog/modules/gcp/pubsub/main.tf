# УРОВЕНЬ 1 — MODULE.
# «Как создать топик Pub/Sub с подписками и выдать права на подписки».

resource "google_pubsub_topic" "this" {
  name   = var.topic
  labels = var.labels
}

resource "google_pubsub_subscription" "this" {
  for_each = var.subscriptions

  name                 = each.key
  topic                = google_pubsub_topic.this.id
  ack_deadline_seconds = each.value.ack_deadline_seconds
  labels               = var.labels
}

# Каждому участнику из var.subscribers — роль subscriber на каждую подписку.
resource "google_pubsub_subscription_iam_member" "subscriber" {
  for_each = {
    for pair in setproduct(keys(var.subscriptions), var.subscribers) :
    "${pair[0]}/${pair[1]}" => { subscription = pair[0], member = pair[1] }
  }

  subscription = google_pubsub_subscription.this[each.value.subscription].name
  role         = "roles/pubsub.subscriber"
  member       = each.value.member
}
