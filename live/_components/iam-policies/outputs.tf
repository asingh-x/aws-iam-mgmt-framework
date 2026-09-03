output "policy_arns" {
  description = "Map of request name to created policy ARN."
  value       = { for k, m in module.policy : k => m.arn }
}

output "policy_names" {
  description = "Map of request name to created policy name."
  value       = { for k, m in module.policy : k => m.name }
}
