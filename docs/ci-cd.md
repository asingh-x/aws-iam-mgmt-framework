# CI/CD pipeline contract

This repo does not ship a CI/CD implementation. It defines a pipeline
*contract* -- three required stages and the invariants they must uphold --
that any CI system can satisfy: GitHub Actions, GitLab CI, Jenkins,
CircleCI, Buildkite, or whatever your team already runs. Build the
pipeline in your own tooling; this document says what each stage must do
and why.

## Required stages

### 1. Validate -- every PR and push

Fully offline: no AWS credentials or network access to AWS needed.

1. Compute the set of changed files (however your CI tool exposes a diff
   against the target branch).
2. `python3 scripts/validate_requests.py <changed request files>` --
   guardrail-validates just the changed requests. Run with no arguments to
   validate every request under `requests/` instead.
3. `python3 -m unittest discover -s tests -v` -- the guardrail and
   changed-target test suite.
4. `terraform fmt -check -recursive`
5. `terragrunt hclfmt --check --working-dir=.`

`make check` runs this whole sequence locally (see
[Local testing](#local-testing) below) -- use it to reproduce a CI failure
without waiting on a pipeline run.

### 2. Plan -- every PR

1. Feed the same changed-file list to `scripts/changed_targets.py` (reads
   paths from `argv`, or from stdin if no paths are given; pass
   `--rollout-manifest <path>` to supply a rollout manifest for a
   `modules/`/`guardrails/` change -- see the script's docstring and
   `main()` for the exact CLI contract rather than assuming flags).
2. Its JSON output carries two fields that drive everything downstream:
   - `controlled_rollout_required` -- `true` means a `modules/` or
     `guardrails/` change was detected with no rollout manifest supplied.
     **The pipeline must refuse to plan or apply anything automatically
     when this is true**, regardless of which CI tool is running it. Stop
     and surface the message; don't work around it.
   - `targets` -- the exact `{environment, account_id}` list to act on.
3. For each target, `cd live/<environment>/<account_id>/` and run
   `terragrunt plan` there, using short-lived AWS credentials.
   OIDC federation is the recommended pattern: GitHub Actions has
   `aws-actions/configure-aws-credentials` with `id-token: write`; GitLab
   CI, Jenkins, CircleCI, and Buildkite each have their own OIDC-to-AWS
   federation equivalent. The requirement is the pattern -- federated,
   short-lived, scoped -- not a specific action or plugin.
4. Make the plan output visible to reviewers, however your CI tool
   supports it: a PR comment, a job summary, or just the build log.
5. **This stage never runs `terragrunt apply`.**

### 3. Apply -- only after a human approves the plan

Runs after explicit human approval -- a merge to `main`, a required
reviewer, or a manual approval gate, depending on what your CI tool
supports.

1. Re-derive the same targets via `scripts/changed_targets.py` (same
   changed-file list, same rollout-manifest rules as the plan stage).
2. Run `terragrunt apply` for exactly those targets, nothing more.
3. This stage needs write credentials: still short-lived/OIDC, still
   scoped to `arn:aws:iam::<account_id>:role/OrgIAMProvisioner_DoNotDelete`
   for the account being applied to.
4. It must require an explicit approval step of whatever kind your CI
   tool supports -- a required reviewer, a manual gate, a protected-branch
   merge. Least aggressive: trigger apply manually per target. More
   automated: auto-apply, but only after an explicit approval step --
   never unconditionally on every merge to `main`.

## Hard invariants

These hold no matter which CI tool implements the contract above. They
are the actual safety guarantees this framework depends on:

- **Account isolation.** `scripts/changed_targets.py` guarantees a change
  under one account's request tree only ever targets that account --
  verified by this repo's own test suite
  (`tests/test_framework.py::TestChangedTargets`).
- **Controlled rollout.** A `modules/` or `guardrails/` change never
  auto-targets every account. It requires an explicit rollout manifest.
- **Apply is never automatic on every merge to `main` by default.** It
  must be gated -- at minimum a manual trigger per target, or auto-apply
  gated behind an explicit approval step.
- **No long-lived credentials.** No plan or apply step should ever need
  long-lived AWS credentials committed as CI secrets. OIDC or an
  equivalent short-lived federation mechanism only.

## Required repository configuration

Whatever CI tool you use needs to provide:

- **(a)** a way to compute changed files for a PR/push (built into most
  CI tools, or derivable from `git diff` against the target branch).
- **(b)** OIDC-federated (or equivalent) short-lived AWS credentials,
  scoped per environment/account -- read-only for the plan stage,
  write-scoped to `OrgIAMProvisioner_DoNotDelete` for the apply stage.
- **(c)** a state bucket and locking mechanism, already configured via
  `live/root.hcl`. That file reads `TG_STATE_BUCKET`, `TG_STATE_REGION`
  (defaults to `us-east-1`), and `TG_STATE_DYNAMODB_TABLE` (optional --
  falls back to S3's native lockfile locking on Terraform >= 1.10 if
  unset) as environment variables. Set them however your CI tool exposes
  environment/secret variables; no other config surface is needed.

## Reference implementation

This repo used to ship a literal GitHub Actions implementation of exactly
this contract; reconstruct one from the stage descriptions above, or ask
your platform team's CI expert to adapt an equivalent pipeline in
whatever tool you use.

## Local testing

No AWS credentials or network access to AWS are required for any of
this.

```bash
# Guardrail + changed-target Python tests (23 cases)
python3 -m unittest discover -s tests -v

# Validate every real request file
python3 scripts/validate_requests.py

# Terraform formatting
terraform fmt -check -recursive

# Terraform module tests (mock AWS provider -- no credentials, no network
# calls to AWS; each module directory needs `terraform init -backend=false`
# once first)
(cd modules/iam-user && terraform test)
(cd modules/iam-role && terraform test)
(cd modules/iam-policy && terraform test)
(cd modules/iam-group && terraform test)

# Terragrunt formatting
terragrunt hclfmt --check --working-dir=.
```

Or run the equivalent of the whole Validate stage in one shot:

```bash
make check   # validate + test + fmt-check + tf-validate + tf-test
```

`terraform validate` also runs cleanly (with `-backend=false`) against
every module and every `live/_components/iam-*` aggregator (`make
tf-validate`). Full `terragrunt plan`/`validate` against the `live/`
units is **not** run locally, because Terragrunt's generated S3 backend
would require a real bucket and AWS credentials to initialize; instead,
`terragrunt render-json` is used to confirm each unit's HCL parses and its
`inputs` resolve correctly (state key, generated provider, and the
`requests` map) without touching AWS.
