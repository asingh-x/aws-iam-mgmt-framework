# Intentionally never creates aws_iam_access_key or
# aws_iam_user_login_profile: credentials must never round-trip through
# Terraform state. A separate key-rotation service owns that lifecycle
# (see README.md).

locals {
  application = coalesce(var.application, var.name)

  tags = {
    Owner           = var.owner
    Name            = local.application
    Environment     = var.environment
    ManagedBy       = "terraform"
    ExceptionTicket = var.exception_ticket
    ExpiresOn       = var.expires_on
  }
}

resource "aws_iam_user" "this" {
  name                 = var.name
  permissions_boundary = var.permissions_boundary_arn
  tags                 = local.tags
}

resource "aws_iam_policy" "custom" {
  name        = var.custom_policy_name
  description = "Custom policy for legacy IAM user ${var.name}"
  path        = "/org/workloads/"
  policy      = var.custom_policy_json
  tags        = local.tags
}

resource "aws_iam_user_policy_attachment" "custom" {
  user       = aws_iam_user.this.name
  policy_arn = aws_iam_policy.custom.arn
}
