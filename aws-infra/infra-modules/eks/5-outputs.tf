output "eks_name" {
    value = aws_eks_cluster.this.name
}

output "openid_provider_arn" {
    value = one(aws_iam_openid_connect_provider.this[*].arn)
}
