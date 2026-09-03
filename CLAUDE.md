# AWS IAM Platform -- Claude instructions

A Terraform/Terragrunt framework for centrally managing account-local IAM
users, roles, groups, and customer-managed policies across many AWS
accounts. Start with [README.md](README.md); deeper reference lives in
[docs/](docs/).

## Ownership model

Everything in this repo, including `requests/**`, is platform-team-owned.
Application teams never edit files here -- they file a ticket, and the
platform team authors the `request.yaml` from it. See
[docs/architecture.md](docs/architecture.md) and the
[new-iam-request skill](.claude/skills/new-iam-request/SKILL.md) for that
workflow.

## Hard safety rules

- **Never run `terraform apply`, `terraform destroy`, `terragrunt apply`,
  or `terragrunt destroy` against a real backend without asking the user
  first, every time** -- not just once at the start of a session. A prior
  "yes" for one apply does not cover the next one.
- **Never contact real AWS** (including read-only calls like
  `aws sts get-caller-identity`) unless the user has explicitly asked for
  real-account testing in the current conversation. Local validation and
  `terraform test` (mock provider) never need real credentials -- prefer
  those.
- **Never commit a real AWS account ID, ARN, or hostname** anywhere in
  this repo -- example/docs/test content. Use a clearly fake placeholder
  (e.g. `999999999999`). This repo may go public.
- **Never create `aws_iam_access_key` or `aws_iam_user_login_profile`**,
  and never put a secret value in any file or Terraform state. See
  [docs/security.md](docs/security.md) for why and how key rotation
  works instead.
- **A `modules/` or `guardrails/` change must never auto-deploy to every
  account.** `scripts/changed_targets.py` enforces this with a controlled-
  rollout gate; don't work around it.
- If asked to loosen a guardrail (wildcard actions/resources, an
  unapproved AWS-managed policy, etc.), don't just do it -- confirm intent
  first. See [docs/validation-rules.md](docs/validation-rules.md) for
  what's currently enforced and how to extend it deliberately.
- **Removing a user/role/policy/group is `apply`, not `destroy`.** One
  account's state file covers everything for that account, so
  `terragrunt destroy` tears down every user/role/policy/group in that
  account, not just the one being removed. See
  [docs/deleting-resources.md](docs/deleting-resources.md).

## Common commands

Run `make help` for the full list. The ones you'll use most:

```bash
make check       # everything: validate + test + fmt-check + tf-validate + tf-test
make validate    # guardrail-validate every request under requests/
make test        # Python test suite (tests/test_framework.py)
make fmt-check   # terraform fmt + terragrunt hclfmt, check-only
make new-request COMPONENT=roles ENVIRONMENT=prod ACCOUNT_ID=999999999999 NAME=foo
```

All of `make check` runs fully offline -- no AWS credentials or network
access to AWS required.

## Key locations

- `requests/<env>/<account_id>/<component>/<name>/` -- one request per
  identity/policy. `<component>` is `users` / `roles` / `policies` /
  `groups`.
- `modules/iam-*` -- single-identity Terraform modules, each with its own
  `terraform test` (mock provider) suite under `tests/`.
- `live/_components/iam-*` -- thin `for_each` aggregators, one per
  component. `live/_components/iam-account` composes all four into a
  single Terraform run. `live/<env>/<account_id>/terragrunt.hcl` (a
  sibling of that account's `account.hcl`, not nested under a component
  subdirectory) wires `iam-account` to one Terragrunt unit with one state
  key per account -- not one per component.
- `guardrails/*.yaml`, `guardrails/permissions-boundary.json` -- the
  allow-lists and policy restrictions `scripts/validate_requests.py`
  enforces. Full rule list in
  [docs/validation-rules.md](docs/validation-rules.md).
- `scripts/validate_requests.py`, `scripts/changed_targets.py`,
  `scripts/scaffold_request.py` -- guardrail validation, changed-file to
  deploy-target mapping, and new-request scaffolding, respectively.
