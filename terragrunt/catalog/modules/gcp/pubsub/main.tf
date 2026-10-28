# LEVEL 1 — MODULE.
# "How to create a Pub/Sub topic with subscriptions and grant access to them".

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

# Every member in var.subscribers gets the subscriber role on every subscription.
resource "google_pubsub_subscription_iam_member" "subscriber" {
  for_each = {
    for pair in setproduct(keys(var.subscriptions), var.subscribers) :
    "${pair[0]}/${pair[1]}" => { subscription = pair[0], member = pair[1] }
  }

  subscription = google_pubsub_subscription.this[each.value.subscription].name
  role         = "roles/pubsub.subscriber"
  member       = each.value.member
}
