# Validation rules (guardrails)

Enforced by `scripts/validate_requests.py`, entirely offline:

- `account_id` must be present and exactly 12 digits.
- The request's `account_id` must match the account directory it's stored
  under (`requests/<env>/<ACCOUNT_DIR>/...`).
- `environment` must be present.
- `owner` (and an identity/policy `name`) must be present.
- For an IAM user: `business_reason`, `exception_ticket`, and `expires_on`
  are all mandatory, and `expires_on` must not be in the past.
- For a role or group: every `policies.aws_managed` ARN must be in
  `guardrails/allowed-aws-managed-policies.yaml`; at least one of
  `policies.aws_managed` / `policies.custom` must be set.
- Every referenced policy JSON file must exist and parse as valid JSON.
- No policy statement may use `Action: "*"`.
- No policy statement may use `Resource: "*"` unless every action in that
  statement is on the (currently empty)
  `resource_wildcard_allowed_actions` allow-list in
  `guardrails/prohibited-actions.yaml`.
- No policy statement may use `NotAction` or `NotResource`.
- No policy statement may use an action prefixed `iam:`, `organizations:`,
  `account:`, or `aws-portal:` (IAM administration, AWS Organizations
  administration, and account-management actions respectively).

If `IAM_PLATFORM_ENABLE_ACCESS_ANALYZER=1` is explicitly set **and** the
AWS CLI is installed, the validator also runs
`aws accessanalyzer validate-policy` against each referenced policy
document as a best-effort, non-fatal extra check -- its absence, failure,
or any output never changes the pass/fail result, so local tests never
depend on it. This is opt-in on purpose: merely having the AWS CLI on
`PATH` is not enough to trigger it, even if that CLI happens to have live
credentials configured for some unrelated account -- this validator must
never contact AWS unless a human has explicitly turned that on.

## Allowed AWS-managed policies

`guardrails/allowed-aws-managed-policies.yaml` currently allows:

```
arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess
arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

`AmazonS3ReadOnlyAccess` is deliberately broad: it grants read access to
every S3 bucket in the account, not just the one your application needs.
Prefer a custom, single-bucket-scoped policy instead (see
`requests/prod/999999999999/policies/sandbox-standalone-read/` for the
shape of a standalone policy request) unless you genuinely need
account-wide read access.

## How to add another approved AWS-managed policy

Add an entry to `guardrails/allowed-aws-managed-policies.yaml`:

```yaml
  - arn: arn:aws:iam::aws:policy/<PolicyName>
    note: "Why this is safe to hand to application teams, and any caveats."
```

This is a change under `guardrails/`, so it goes through the
controlled-rollout path in CI (no automatic org-wide plan/apply) -- it
needs explicit platform-team review and, if it should take effect broadly,
an explicit rollout manifest.

## How to attach AWS-managed policies

List their ARNs under `policies.aws_managed` in a role or group request.
Every ARN must already appear in
`guardrails/allowed-aws-managed-policies.yaml` -- anything else is
rejected. To add a new one, see above.

## How to add an EC2 instance profile

Set `create_instance_profile: true` in a role request whose trust service
is `ec2.amazonaws.com`. The `iam-role` module then also creates an
`aws_iam_instance_profile` bound to the role.
