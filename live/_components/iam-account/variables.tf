variable "permissions_boundary_arn" {
  description = "ARN of the mandatory permissions boundary policy for this account."
  type        = string
}

variable "users_requests" {
  description = "One entry per legacy IAM user request under requests/<env>/<account>/users/*/request.yaml."
  type = map(object({
    name             = string
    owner            = string
    environment      = string
    exception_ticket = string
    expires_on       = string
    policy_json      = string
  }))
  default = {}
}

variable "roles_requests" {
  description = "One entry per IAM role request under requests/<env>/<account>/roles/*/request.yaml."
  type = map(object({
    name                    = string
    owner                   = string
    environment             = string
    trust_service_principal = string
    aws_managed_policy_arns = list(string)
    custom_policies = list(object({
      name        = string
      policy_json = string
    }))
    create_instance_profile = bool
    exception_ticket        = string
    expires_on              = string
  }))
  default = {}
}

variable "policies_requests" {
  description = "One entry per standalone policy request under requests/<env>/<account>/policies/*/request.yaml."
  type = map(object({
    name        = string
    owner       = string
    environment = string
    description = string
    policy_json = string
  }))
  default = {}
}

variable "groups_requests" {
  description = "One entry per IAM group request under requests/<env>/<account>/groups/*/request.yaml."
  type = map(object({
    name                    = string
    owner                   = string
    environment             = string
    aws_managed_policy_arns = list(string)
    custom_policies = list(object({
      name        = string
      policy_json = string
    }))
    members = list(string)
  }))
  default = {}
}
