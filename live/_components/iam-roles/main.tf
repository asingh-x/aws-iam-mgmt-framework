module "role" {
  source = "../../../modules/iam-role"

  for_each = var.requests

  name                     = each.value.name
  owner                    = each.value.owner
  environment              = each.value.environment
  exception_ticket         = each.value.exception_ticket
  expires_on               = each.value.expires_on
  trust_service_principal  = each.value.trust_service_principal
  permissions_boundary_arn = var.permissions_boundary_arn
  aws_managed_policy_arns  = each.value.aws_managed_policy_arns
  custom_policies          = each.value.custom_policies
  create_instance_profile  = each.value.create_instance_profile
}
