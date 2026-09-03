module "user" {
  source = "../../../modules/iam-user"

  for_each = var.requests

  name                     = each.value.name
  owner                    = each.value.owner
  environment              = each.value.environment
  exception_ticket         = each.value.exception_ticket
  expires_on               = each.value.expires_on
  permissions_boundary_arn = var.permissions_boundary_arn
  custom_policy_name       = "${each.value.name}-custom"
  custom_policy_json       = each.value.policy_json
}
