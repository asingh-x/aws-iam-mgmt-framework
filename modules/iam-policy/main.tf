locals {
  application = coalesce(var.application, var.name)

  base_tags = {
    Owner       = var.owner
    Name        = local.application
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  optional_tags = merge(
    var.exception_ticket != "" ? { ExceptionTicket = var.exception_ticket } : {},
    var.expires_on != "" ? { ExpiresOn = var.expires_on } : {},
  )

  tags = merge(local.base_tags, local.optional_tags)
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = var.description
  path        = var.path
  policy      = var.policy_json
  tags        = local.tags
}
