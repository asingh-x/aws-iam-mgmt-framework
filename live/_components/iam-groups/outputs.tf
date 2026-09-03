output "group_names" {
  description = "Map of request name to created IAM group name."
  value       = { for k, m in module.group : k => m.group_name }
}

output "group_arns" {
  description = "Map of request name to created IAM group ARN."
  value       = { for k, m in module.group : k => m.group_arn }
}

output "custom_policy_arns" {
  description = "Map of request name to that group's custom policy name/ARN map."
  value       = { for k, m in module.group : k => m.custom_policy_arns }
}

output "members" {
  description = "Map of request name to the group's managed member list."
  value       = { for k, m in module.group : k => m.members }
}
