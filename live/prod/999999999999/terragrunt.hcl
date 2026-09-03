include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config("account.hcl")
  account_id   = local.account_vars.locals.account_id
  environment  = local.account_vars.locals.environment

  # repo has no .git directory in this exercise, so get_repo_root() can't be
  # used -- derive the repo root from the location of live/root.hcl instead.
  repo_root = dirname(dirname(find_in_parent_folders("root.hcl")))

  account_requests_dir = "${local.repo_root}/requests/${local.environment}/${local.account_id}"

  # -- users --
  users_dir   = "${local.account_requests_dir}/users"
  users_names = [for f in try(fileset(local.users_dir, "*/request.yaml"), []) : dirname(f)]
  users_parsed = {
    for name in local.users_names :
    name => yamldecode(file("${local.users_dir}/${name}/request.yaml"))
  }
  users_requests = {
    for name, r in local.users_parsed :
    name => {
      name             = r.identity.name
      owner            = r.identity.owner
      environment      = r.environment
      exception_ticket = r.exception_ticket
      expires_on       = r.expires_on
      policy_json      = file("${local.users_dir}/${name}/${r.policy.file}")
    }
  }

  # -- roles --
  roles_dir   = "${local.account_requests_dir}/roles"
  roles_names = [for f in try(fileset(local.roles_dir, "*/request.yaml"), []) : dirname(f)]
  roles_parsed = {
    for name in local.roles_names :
    name => yamldecode(file("${local.roles_dir}/${name}/request.yaml"))
  }
  roles_requests = {
    for name, r in local.roles_parsed :
    name => {
      name                    = r.identity.name
      owner                   = r.identity.owner
      environment             = r.environment
      trust_service_principal = r.trust.service
      aws_managed_policy_arns = try(r.policies.aws_managed, [])
      custom_policies = [
        for c in try(r.policies.custom, []) : {
          name        = c.name
          policy_json = file("${local.roles_dir}/${name}/${c.file}")
        }
      ]
      create_instance_profile = try(r.create_instance_profile, false)
      exception_ticket        = try(r.exception_ticket, "")
      expires_on              = try(r.expires_on, "")
    }
  }

  # -- policies --
  policies_dir   = "${local.account_requests_dir}/policies"
  policies_names = [for f in try(fileset(local.policies_dir, "*/request.yaml"), []) : dirname(f)]
  policies_parsed = {
    for name in local.policies_names :
    name => yamldecode(file("${local.policies_dir}/${name}/request.yaml"))
  }
  policies_requests = {
    for name, r in local.policies_parsed :
    name => {
      name        = r.name
      owner       = r.owner
      environment = r.environment
      description = try(r.description, "")
      policy_json = file("${local.policies_dir}/${name}/${r.file}")
    }
  }

  # -- groups --
  groups_dir   = "${local.account_requests_dir}/groups"
  groups_names = [for f in try(fileset(local.groups_dir, "*/request.yaml"), []) : dirname(f)]
  groups_parsed = {
    for name in local.groups_names :
    name => yamldecode(file("${local.groups_dir}/${name}/request.yaml"))
  }
  groups_requests = {
    for name, r in local.groups_parsed :
    name => {
      name                    = r.identity.name
      owner                   = r.identity.owner
      environment             = r.environment
      aws_managed_policy_arns = try(r.policies.aws_managed, [])
      custom_policies = [
        for c in try(r.policies.custom, []) : {
          name        = c.name
          policy_json = file("${local.groups_dir}/${name}/${c.file}")
        }
      ]
      members = try(r.members, [])
    }
  }
}

terraform {
  source = "${local.repo_root}//live/_components/iam-account"
}

inputs = {
  permissions_boundary_arn = "arn:aws:iam::${local.account_id}:policy/org-mandatory-permissions-boundary"
  users_requests           = local.users_requests
  roles_requests           = local.roles_requests
  policies_requests        = local.policies_requests
  groups_requests          = local.groups_requests
}
