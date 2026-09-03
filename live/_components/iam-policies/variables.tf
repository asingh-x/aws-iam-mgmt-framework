variable "requests" {
  description = "One entry per standalone policy request under requests/<env>/<account>/policies/*/request.yaml."
  type = map(object({
    name        = string
    owner       = string
    environment = string
    description = string
    policy_json = string
  }))
}
