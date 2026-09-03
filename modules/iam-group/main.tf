# IAM groups have no permissions_boundary attribute and cannot be tagged --
# both are hard AWS API limitations (boundaries and tags only apply to
# users, roles, and policies). So unlike modules/iam-user and
# modules/iam-role, this group carries no boundary and no tags of its own;
# the standard tag set is instead applied to the custom policy this module
# creates, which AWS does allow to be tagged.

locals {
  application = coalesce(var.application, var.name)

  tags = {
    Owner       = var.owner
    Name        = local.application
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  optional_tags = merge(
    var.exception_ticket != "" ? { ExceptionTicket = var.exception_ticket } : {},
    var.expires_on != "" ? { ExpiresOn = var.expires_on } : {},
  )

  all_tags = merge(local.tags, local.optional_tags)

  custom_policies_by_name = { for p in var.custom_policies : p.name => p }
}

resource "aws_iam_group" "this" {
  name = var.name
}

resource "aws_iam_group_policy_attachment" "aws_managed" {
  for_each = toset(var.aws_managed_policy_arns)

  group      = aws_iam_group.this.name
  policy_arn = each.value
}

resource "aws_iam_policy" "custom" {
  for_each = local.custom_policies_by_name

  name        = each.value.name
  description = "Custom policy for IAM group ${var.name}"
  path        = "/org/workloads/"
  policy      = each.value.policy_json
  tags        = local.all_tags
}

resource "aws_iam_group_policy_attachment" "custom" {
  for_each = aws_iam_policy.custom

  group      = aws_iam_group.this.name
  policy_arn = each.value.arn
}

resource "aws_iam_group_membership" "this" {
  count = length(var.members) > 0 ? 1 : 0

  name  = "${var.name}-membership"
  group = aws_iam_group.this.name
  users = var.members
}
