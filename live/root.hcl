# Shared root config included by every account/component unit under live/.
# Defines per-unit remote state (one state file per account+component) and
# generates the AWS provider that assumes the account-local provisioning
# role. Nothing here ever contacts AWS during local validate/test/plan --
# there is no real backend configured for this exercise, and the
# assume_role block is only ever exercised by a real CI/CD run against a
# real account with real OIDC-derived credentials.

locals {
  # account.hcl is now a sibling of the child terragrunt.hcl (one unit per
  # account, not one per component), not a parent -- find_in_parent_folders
  # would never find it. A plain relative reference resolves against the
  # child unit's own directory, same as every other path here.
  account_vars = read_terragrunt_config("account.hcl")
  account_id   = local.account_vars.locals.account_id
  environment  = local.account_vars.locals.environment

  state_bucket = get_env("TG_STATE_BUCKET", "REPLACE_ME_STATE_BUCKET")
  state_region = get_env("TG_STATE_REGION", "us-east-1")
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket       = local.state_bucket
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.state_region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.state_region}"

      assume_role {
        role_arn = "arn:aws:iam::${local.account_id}:role/OrgIAMProvisioner_DoNotDelete"
      }
    }
  EOF
}
