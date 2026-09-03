module "group" {
  source = "../../../modules/iam-group"

  for_each = var.requests

  name                    = each.value.name
  owner                   = each.value.owner
  environment             = each.value.environment
  aws_managed_policy_arns = each.value.aws_managed_policy_arns
  custom_policies         = each.value.custom_policies
  members                 = each.value.members
}
