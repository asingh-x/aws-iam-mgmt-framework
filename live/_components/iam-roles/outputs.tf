output "role_names" {
  description = "Map of request name to created IAM role name."
  value       = { for k, m in module.role : k => m.role_name }
}

output "role_arns" {
  description = "Map of request name to created IAM role ARN."
  value       = { for k, m in module.role : k => m.role_arn }
}

output "custom_policy_arns" {
  description = "Map of request name to that role's custom policy name/ARN map."
  value       = { for k, m in module.role : k => m.custom_policy_arns }
}

output "instance_profile_arns" {
  description = "Map of request name to instance profile ARN, where created."
  value       = { for k, m in module.role : k => m.instance_profile_arn }
}
