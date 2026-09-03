output "user_names" {
  description = "Map of request name to created IAM user name."
  value       = { for k, m in module.user : k => m.user_name }
}

output "user_arns" {
  description = "Map of request name to created IAM user ARN."
  value       = { for k, m in module.user : k => m.user_arn }
}

output "policy_arns" {
  description = "Map of request name to the user's custom policy ARN."
  value       = { for k, m in module.user : k => m.policy_arn }
}
