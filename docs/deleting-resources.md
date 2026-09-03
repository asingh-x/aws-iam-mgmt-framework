# Decommissioning a user, role, policy, or group

## The mechanism

Each `live/_components/iam-*` aggregator builds a Terraform `for_each` map
from whatever `request.yaml` files exist under
`requests/<env>/<account_id>/<component>/`. Delete a request's directory,
and its key simply disappears from that map on the next plan/apply --
Terraform destroys exactly that identity's resources (the role/user/group,
its custom policy, its attachments) and leaves every other identity in
that account untouched -- including identities in the account's other
components -- because they're still separate map entries, either in the
same aggregator's map or in one of the other three aggregators nested
alongside it inside `live/_components/iam-account`. All four aggregators
share that one account-level state file (see
[architecture.md](architecture.md)), but that doesn't make their
`for_each` maps collide with each other.

## Steps

1. **Delete the request directory**: remove
   `requests/<env>/<account_id>/<component>/<name>/` entirely (the
   `request.yaml` and any policy JSON alongside it).
2. **Open a PR** with just that deletion. `scripts/changed_targets.py`
   scopes to the same `{environment, account_id}` target it would for an
   add or edit -- deletion isn't a special case.
3. **Review the plan**: whatever CI stage runs `terragrunt plan` for that
   target (see [docs/ci-cd.md](ci-cd.md)) will now show a *destroy* plan.
   Confirm it destroys only the resources for the identity you removed --
   nothing else in that account's state should show as changed.
4. **Apply it**: run `terragrunt apply` (see the warning below) for that
   `live/<env>/<account_id>/` unit, using the same care as any other
   real-account action -- confirm with whoever owns that apply gate
   before running it, the same as for a create.

## Use `apply`, never `destroy`, to remove one identity

`terragrunt destroy` tears down **every** resource that account's state
file tracks -- every user, every role, every policy, and every group in
that account, across all four components, not just the one you deleted
the request for. Because one account now has exactly one Terraform state
file shared by users/roles/policies/groups alike, `destroy` is no longer
scoped to "one component's worth of resources" the way it might once
have been -- it's scoped to that account's *entire* IAM surface managed by
this framework. `terragrunt apply` is what reconciles state to match the
current `for_each` maps, which correctly destroys only the removed
identity while leaving every other identity's resources -- in that
component and every other component of the account -- alone. If you ever
find yourself about to run `destroy` to remove one thing, stop -- that's
the wrong command, and against this account's shared state it is far more
destructive than it might look at first glance.

## Before you delete

Check the request's `owner` (and, for legacy users, `exception_ticket`)
before removing it -- confirm with that owner that nothing still depends
on the identity. A role backing a running Lambda, or a user an
application still authenticates as, needs coordination first, not just a
deleted file.

## Decommissioning an entire account

Delete both `requests/<env>/<account_id>/` and `live/<env>/<account_id>/`.
Note this does **not** clean up that account's state object in the
remote state bucket (the single `<env>/<account_id>/terraform.tfstate`
key stays put, holding whatever was destroyed by prior applies -- normally
empty by this point, but still an orphaned object). Delete that state
object from the bucket yourself if you want a fully clean removal; it
doesn't cost or risk anything just sitting there, but it's not
automatically swept.
