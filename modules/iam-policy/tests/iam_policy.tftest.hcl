mock_provider "aws" {}

run "creates_policy_with_path_and_tags" {
  command = plan

  variables {
    name        = "ReportingS3Read"
    description = "Read access to the reporting bucket"
    policy_json = jsonencode({ Version = "2012-10-17", Statement = [] })
    owner       = "reporting-team@example.com"
    environment = "production"
  }

  assert {
    condition     = aws_iam_policy.this.path == "/org/workloads/"
    error_message = "default path must be /org/workloads/"
  }

  assert {
    condition     = aws_iam_policy.this.tags["Owner"] == "reporting-team@example.com"
    error_message = "Owner tag missing"
  }

  assert {
    condition     = aws_iam_policy.this.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag missing"
  }

  assert {
    condition     = aws_iam_policy.this.tags["Environment"] == "production"
    error_message = "Environment tag missing"
  }

  assert {
    condition     = !contains(keys(aws_iam_policy.this.tags), "ExceptionTicket")
    error_message = "ExceptionTicket must be absent when not supplied"
  }
}

run "includes_optional_tags_when_supplied" {
  command = plan

  variables {
    name             = "LegacyAppPolicy"
    policy_json      = jsonencode({ Version = "2012-10-17", Statement = [] })
    owner            = "reporting-team@example.com"
    environment      = "production"
    exception_ticket = "SEC-1234"
    expires_on       = "2027-03-31"
  }

  assert {
    condition     = aws_iam_policy.this.tags["ExceptionTicket"] == "SEC-1234"
    error_message = "ExceptionTicket tag not applied"
  }

  assert {
    condition     = aws_iam_policy.this.tags["ExpiresOn"] == "2027-03-31"
    error_message = "ExpiresOn tag not applied"
  }
}
