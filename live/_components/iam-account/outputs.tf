output "user_names" {
  value = module.users.user_names
}

output "user_arns" {
  value = module.users.user_arns
}

output "user_policy_arns" {
  value = module.users.policy_arns
}

output "role_names" {
  value = module.roles.role_names
}

output "role_arns" {
  value = module.roles.role_arns
}

output "role_custom_policy_arns" {
  value = module.roles.custom_policy_arns
}

output "role_instance_profile_arns" {
  value = module.roles.instance_profile_arns
}

output "policy_arns" {
  value = module.policies.policy_arns
}

output "group_names" {
  value = module.groups.group_names
}

output "group_arns" {
  value = module.groups.group_arns
}

output "group_custom_policy_arns" {
  value = module.groups.custom_policy_arns
}

output "group_members" {
  value = module.groups.members
}
