output "arn" {
  description = "ARN of the customer-managed policy."
  value       = aws_iam_policy.this.arn
}

output "name" {
  description = "Name of the customer-managed policy."
  value       = aws_iam_policy.this.name
}
