variable "requests" {
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
}
