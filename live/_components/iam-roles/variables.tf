variable "requests" {
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
}

variable "permissions_boundary_arn" {
  description = "ARN of the mandatory permissions boundary policy for this account."
  type        = string
}
