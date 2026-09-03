# Composes all four component aggregators into a single Terraform run so
# one account has exactly one state file, covering every users/roles/
# policies/groups request for that account together.

module "users" {
  source = "../iam-users"

  requests                 = var.users_requests
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "roles" {
  source = "../iam-roles"

  requests                 = var.roles_requests
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "policies" {
  source = "../iam-policies"

  requests = var.policies_requests
}

module "groups" {
  source = "../iam-groups"

  requests = var.groups_requests
}
