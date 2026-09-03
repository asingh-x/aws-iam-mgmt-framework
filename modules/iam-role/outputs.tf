output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN of the IAM role."
  value       = aws_iam_role.this.arn
}

output "custom_policy_arns" {
  description = "Map of custom policy name to ARN, for policies created by this role."
  value       = { for k, p in aws_iam_policy.custom : k => p.arn }
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile, if created; otherwise null."
  value       = try(aws_iam_instance_profile.this[0].arn, null)
}
