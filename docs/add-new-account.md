# How to add another AWS account

1. Create `requests/prod/<new_account_id>/` (with `users/`, `roles/`,
   `policies/`, and/or `groups/` subdirectories as needed) and add request
   files.
2. Create `live/prod/<new_account_id>/account.hcl`:
   ```hcl
   locals {
     account_id  = "<new_account_id>"
     environment = "prod"
   }
   ```
3. Copy the single `terragrunt.hcl` file from an existing account (e.g.
   `live/prod/999999999999/terragrunt.hcl`) into
   `live/prod/<new_account_id>/terragrunt.hcl`, as a sibling of the
   `account.hcl` you just created (not nested under any subdirectory).
   The file is identical across accounts -- it derives `account_id` and
   `environment` from its own `account.hcl`, builds the users/roles/
   policies/groups request maps itself from
   `requests/<environment>/<new_account_id>/`, and points
   `terraform.source` at the shared `live/_components/iam-account`
   component -- so no per-account edits are needed inside it.
4. Open a PR. `scripts/changed_targets.py` will select only the new
   account's targets; your CI pipeline's plan stage (see
   [ci-cd.md](ci-cd.md)) will plan only those.
