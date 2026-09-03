# Architecture

## Why single-identity modules + aggregators

The `modules/iam-*` directories are deliberately single-identity (one user,
one role, one policy, or one group per module call) so each is small,
independently testable with a mock AWS provider, and reusable. The
`live/_components/iam-*` directories are thin aggregators that `for_each`
over every request found for that account+component and call the matching
module once per identity -- this is what lets one Terragrunt unit (and one
state file) hold an arbitrary number of users/roles/policies/groups for
that account while keeping the leaf modules simple.

Four components exist today:

| Component | Module | Aggregator | Status |
|---|---|---|---|
| `users` | `modules/iam-user` | `live/_components/iam-users` | Example wired up |
| `roles` | `modules/iam-role` | `live/_components/iam-roles` | Example wired up |
| `policies` | `modules/iam-policy` | `live/_components/iam-policies` | Example wired up |
| `groups` | `modules/iam-group` | `live/_components/iam-groups` | Module + aggregator exist and are tested and are composed into every account's unit via `live/_components/iam-account`; no account has an example group `request.yaml` populated yet |

`live/_components/iam-account` composes all four aggregators above as
nested `module` blocks into a single Terraform run. This is the actual
component the per-account `live/<env>/<account_id>/terragrunt.hcl` points
`terraform.source` at -- it's what gives one account exactly one
Terragrunt unit (and one state file) covering every users/roles/policies/
groups request for that account together.

IAM groups have a hard AWS API limitation: they cannot carry a permissions
boundary or tags directly. `modules/iam-group` works around this by
applying the standard tag set to the group's custom policy instead (which
AWS does allow to be tagged), and by accepting a `members` list of
*existing* IAM usernames to add to the group -- it does not create users.

Every path in this repo -- `requests/**` included -- is owned and edited
by the platform team; there is no path application teams touch directly.
`modules/**` and `guardrails/**` changes additionally require controlled
rollout (see [ci-cd.md](ci-cd.md) for the pipeline contract any CI tool
must satisfy; CI/CD itself is not implemented in this repo).

## How an application team actually requests access

Application teams don't open a PR or touch this repo at all. They file a
ticket in the org's ticketing system describing what they need (an IAM
user, a role, a policy, a group -- and why). A platform team member reads
the ticket, writes the corresponding `request.yaml` (and any policy JSON)
under `requests/<environment>/<account_id>/<component>/<name>/`, and opens
the PR themselves. The rest of the pipeline (validation, changed-target
detection, scoped plan) works exactly the same either way -- only the
*source* of the request differs from a self-service model.

## Account-isolated deployment

Every account gets its own Terraform state file
(`<env>/<account_id>/terraform.tfstate`), configured by `live/root.hcl`'s
`remote_state` block using `path_relative_to_include()`. Because state is
never shared across accounts, a change to one account's unit cannot
corrupt or even see another account's state. Within an account, all four
components (users, roles, policies, groups) *do* share that one state
file -- that's the point of `live/_components/iam-account` composing them
together (see above).

`scripts/changed_targets.py` guarantees that CI only *plans* the accounts
an actual change affects:

- A change under `requests/prod/999999999999/users/...` produces exactly
  one target: `{environment: prod, account_id: 999999999999}`. It never
  selects any other account.
- Multiple changed files for the same account -- even across different
  components (users/roles/policies/groups) -- collapse into one target,
  since they're all planned/applied as the same single Terragrunt unit.
- A change under `requests/common/<component>/...` may fan out to every
  account that has a `<component>` directory (since shared/common request
  fragments can affect many accounts at once).
- A change under `modules/` or `guardrails/` **never** auto-selects every
  account. It sets `controlled_rollout_required: true` and refuses to
  produce any targets unless an explicit rollout manifest
  (`rollout/manifest.json`, `{"targets": [...]}`) is supplied via
  `--rollout-manifest`. This is enforced by the script itself, so it holds
  regardless of which CI tool's plan stage calls it -- see
  [ci-cd.md](ci-cd.md).

The environments currently scaffolded under `requests/` and `live/` are
`prod`, `dev`, and `common`. `dev` is empty scaffolding today; `999999999999`
under `prod` is the one illustrative example account with requests wired
up end-to-end.

See the [README](../README.md) for the request-submission flow, and
[add-new-account.md](add-new-account.md) to add another
account.
