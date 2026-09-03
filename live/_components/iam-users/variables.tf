variable "requests" {
  description = "One entry per legacy IAM user request under requests/<env>/<account>/users/*/request.yaml."
  type = map(object({
    name             = string
    owner            = string
    environment      = string
    exception_ticket = string
    expires_on       = string
    policy_json      = string
  }))
}

variable "permissions_boundary_arn" {
  description = "ARN of the mandatory permissions boundary policy for this account."
  type        = string
}
