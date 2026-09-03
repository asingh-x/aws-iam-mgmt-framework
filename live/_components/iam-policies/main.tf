module "policy" {
  source = "../../../modules/iam-policy"

  for_each = var.requests

  name        = each.value.name
  description = each.value.description
  owner       = each.value.owner
  environment = each.value.environment
  policy_json = each.value.policy_json
}
