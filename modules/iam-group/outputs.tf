output "group_name" {
  description = "Name of the IAM group."
  value       = aws_iam_group.this.name
}

output "group_arn" {
  description = "ARN of the IAM group."
  value       = aws_iam_group.this.arn
}

output "custom_policy_arns" {
  description = "Map of custom policy name to ARN, for policies created by this group."
  value       = { for k, p in aws_iam_policy.custom : k => p.arn }
}

output "members" {
  description = "IAM users that are members of this group, as managed by this module."
  value       = try(aws_iam_group_membership.this[0].users, [])
}
