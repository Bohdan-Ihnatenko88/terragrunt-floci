output "topic_id" {
  value = google_pubsub_topic.this.id
}

output "subscriptions" {
  value = [for s in google_pubsub_subscription.this : s.name]
}
