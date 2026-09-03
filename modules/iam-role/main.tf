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

  custom_policies_by_name = { for p in var.custom_policies : p.name => p }

  trust_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = var.trust_service_principal
        }
      }
    ]
  })
}

resource "aws_iam_role" "this" {
  name                 = var.name
  assume_role_policy   = local.trust_policy_json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = local.tags
}

resource "aws_iam_role_policy_attachment" "aws_managed" {
  for_each = toset(var.aws_managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_policy" "custom" {
  for_each = local.custom_policies_by_name

  name        = each.value.name
  description = "Custom policy for IAM role ${var.name}"
  path        = "/org/workloads/"
  policy      = each.value.policy_json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  for_each = aws_iam_policy.custom

  role       = aws_iam_role.this.name
  policy_arn = each.value.arn
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = var.name
  role = aws_iam_role.this.name
  tags = local.tags
}
