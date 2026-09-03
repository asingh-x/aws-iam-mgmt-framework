# Security

## Why access keys are not created by Terraform

`modules/iam-user` never declares `aws_iam_access_key` or
`aws_iam_user_login_profile`, and no request schema in this repo has a
field for a credential value. This is deliberate: Terraform state is
plaintext-readable by anyone with access to the state backend, and a
secret access key or password sitting in state (or in a `plan` output, or
in a PR diff of a `.tfstate` file) is a standing leak waiting to happen.
Keeping credential material entirely out of Terraform's data path means
there is nothing to leak from this pipeline, ever.

### How a separate key-rotation service should work

The `credential` block in a user request (`rotation_days`, `delivery`) is
metadata *for that other service*, not for Terraform:

1. A separate, minimally-scoped Lambda/Step Functions workflow (outside
   this repo) watches for new/rotating legacy IAM users -- e.g. by
   reading the same `requests/**/users/**/request.yaml` files, or a
   change-log of them.
2. It calls `iam:CreateAccessKey` directly against AWS, writes the new key
   straight into AWS Secrets Manager (never to disk, never to a Terraform
   variable), and tags the secret with the user/rotation metadata.
3. On the next rotation cycle (`rotation_days`), it creates a new key,
   updates the secret, waits out an overlap window, then deletes the old
   key (`iam:DeleteAccessKey`).
4. It never touches Terraform state and Terraform never touches it -- the
   two systems only agree on which IAM user exists, not on any secret
   value.

## Safety

This repository, by construction:

- Never runs `terraform apply` from any local test or CI validation job
  (the `plan` workflow only plans; nothing in this repo applies).
- Never contacts AWS during local validation or testing (Terraform module
  tests use `mock_provider`; Terragrunt unit checks use `render-json`).
- Never creates `aws_iam_access_key`, `aws_iam_user_login_profile`, or any
  other real credential.
- Never stores a secret value in any file or in Terraform state.
- Never grants an administrator-equivalent policy through this framework
  (guardrails reject `iam:*`-style escalation, wildcard actions, and
  wildcard resources by default).
- Never shares one Terraform state across accounts -- every account has
  its own state key (all four components of an account -- users, roles,
  policies, groups -- share that one key by design).
- Never auto-deploys a `modules/`/`guardrails/` change to every account;
  that always requires an explicit rollout manifest.
- Every IAM user and role carries a mandatory permissions boundary
  (`guardrails/permissions-boundary.json`); IAM groups cannot carry a
  boundary at all (an AWS API limitation), so only individually-boundaried
  users/roles can be added as group members.
