mock_provider "aws" {}

run "role_with_aws_managed_only" {
  command = plan

  variables {
    name                     = "test-role"
    owner                    = "platform-team@example.com"
    environment              = "production"
    trust_service_principal  = "ec2.amazonaws.com"
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/org-mandatory-permissions-boundary"
    aws_managed_policy_arns  = ["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"]
    custom_policies          = []
    create_instance_profile  = false
  }

  assert {
    condition     = aws_iam_role.this.name == "test-role"
    error_message = "role name mismatch"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.aws_managed) == 1
    error_message = "expected exactly one AWS-managed policy attachment"
  }

  assert {
    condition     = length(aws_iam_policy.custom) == 0
    error_message = "no custom policies should be created for this run"
  }

  assert {
    condition     = length(aws_iam_instance_profile.this) == 0
    error_message = "no instance profile should be created for this run"
  }
}

run "role_with_aws_managed_and_custom" {
  command = apply

  override_resource {
    target = aws_iam_policy.custom
    values = {
      arn = "arn:aws:iam::111111111111:policy/org/workloads/ReportingS3Access"
    }
  }

  variables {
    name                     = "reporting-lambda"
    owner                    = "reporting-team@example.com"
    environment              = "production"
    trust_service_principal  = "lambda.amazonaws.com"
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/org-mandatory-permissions-boundary"
    aws_managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
    custom_policies = [
      {
        name = "ReportingS3Access"
        policy_json = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid      = "WriteReportsOutput"
              Effect   = "Allow"
              Action   = ["s3:PutObject", "s3:GetObject"]
              Resource = "arn:aws:s3:::customer-reports-prod/output/*"
            }
          ]
        })
      }
    ]
    create_instance_profile = false
  }

  assert {
    condition     = strcontains(aws_iam_role.this.assume_role_policy, "lambda.amazonaws.com")
    error_message = "trust policy must reference the lambda service principal"
  }

  assert {
    condition     = length(aws_iam_policy.custom) == 1
    error_message = "expected exactly one custom policy"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.custom) == 1
    error_message = "expected the custom policy to be attached to the role"
  }

  assert {
    condition     = length(aws_iam_instance_profile.this) == 0
    error_message = "no instance profile should be created for this run"
  }
}

run "role_with_instance_profile" {
  command = plan

  variables {
    name                     = "reporting-ec2"
    owner                    = "reporting-team@example.com"
    environment              = "production"
    trust_service_principal  = "ec2.amazonaws.com"
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/org-mandatory-permissions-boundary"
    aws_managed_policy_arns  = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
    custom_policies          = []
    create_instance_profile  = true
  }

  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "expected exactly one instance profile"
  }

  assert {
    condition     = aws_iam_instance_profile.this[0].role == "reporting-ec2"
    error_message = "instance profile not attached to the expected role"
  }
}
