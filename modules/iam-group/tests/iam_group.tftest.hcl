mock_provider "aws" {}

run "group_with_aws_managed_only_no_members" {
  command = plan

  variables {
    name                    = "reporting-group"
    owner                   = "reporting-team@example.com"
    environment             = "production"
    aws_managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"]
    custom_policies         = []
    members                 = []
  }

  assert {
    condition     = aws_iam_group.this.name == "reporting-group"
    error_message = "group name mismatch"
  }

  assert {
    condition     = length(aws_iam_group_policy_attachment.aws_managed) == 1
    error_message = "expected exactly one AWS-managed policy attachment"
  }

  assert {
    condition     = length(aws_iam_policy.custom) == 0
    error_message = "no custom policies should be created for this run"
  }

  assert {
    condition     = length(aws_iam_group_membership.this) == 0
    error_message = "no membership resource should be created when members is empty"
  }
}

run "group_with_custom_policy_and_members" {
  command = apply

  override_resource {
    target = aws_iam_policy.custom
    values = {
      arn = "arn:aws:iam::111111111111:policy/org/workloads/ReportingGroupAccess"
    }
  }

  variables {
    name                    = "reporting-group"
    owner                   = "reporting-team@example.com"
    environment             = "production"
    aws_managed_policy_arns = []
    custom_policies = [
      {
        name = "ReportingGroupAccess"
        policy_json = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid      = "ReadReports"
              Effect   = "Allow"
              Action   = "s3:GetObject"
              Resource = "arn:aws:s3:::customer-reports-prod/*"
            }
          ]
        })
      }
    ]
    members = ["reporting-app", "another-user"]
  }

  assert {
    condition     = length(aws_iam_policy.custom) == 1
    error_message = "expected exactly one custom policy"
  }

  assert {
    condition     = length(aws_iam_group_policy_attachment.custom) == 1
    error_message = "expected the custom policy to be attached to the group"
  }

  assert {
    condition     = length(aws_iam_group_membership.this) == 1
    error_message = "expected a membership resource when members is non-empty"
  }

  assert {
    condition     = length(aws_iam_group_membership.this[0].users) == 2
    error_message = "expected both members to be in the group"
  }
}
