mock_provider "aws" {}

run "creates_user_with_boundary_and_no_credentials" {
  command = apply

  override_resource {
    target = aws_iam_policy.custom
    values = {
      arn = "arn:aws:iam::111111111111:policy/org/workloads/reporting-app-custom"
    }
  }

  variables {
    name                     = "reporting-app"
    owner                    = "reporting-team@example.com"
    environment              = "production"
    exception_ticket         = "SEC-1234"
    expires_on               = "2027-03-31"
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/org-mandatory-permissions-boundary"
    custom_policy_name       = "reporting-app-custom"
    custom_policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ListReportsBucket"
          Effect   = "Allow"
          Action   = "s3:ListBucket"
          Resource = "arn:aws:s3:::customer-reports-prod"
        }
      ]
    })
  }

  assert {
    condition     = aws_iam_user.this.permissions_boundary == "arn:aws:iam::111111111111:policy/org-mandatory-permissions-boundary"
    error_message = "permissions boundary not applied to user"
  }

  assert {
    condition     = aws_iam_user.this.tags["ExceptionTicket"] == "SEC-1234"
    error_message = "ExceptionTicket tag missing"
  }

  assert {
    condition     = aws_iam_user.this.tags["ExpiresOn"] == "2027-03-31"
    error_message = "ExpiresOn tag missing"
  }

  assert {
    condition     = aws_iam_policy.custom.name == "reporting-app-custom"
    error_message = "custom policy not created with expected name"
  }

  assert {
    condition     = aws_iam_user_policy_attachment.custom.policy_arn == aws_iam_policy.custom.arn
    error_message = "custom policy not attached to user"
  }
}
