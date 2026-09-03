variable "name" {
  description = "Name of the IAM group."
  type        = string
}

variable "owner" {
  description = "Owner tag value, applied to the group's custom policy (IAM groups themselves cannot be tagged -- see main.tf)."
  type        = string
}

variable "application" {
  description = "Application tag value, applied to the group's custom policy."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment tag value, applied to the group's custom policy."
  type        = string
}

variable "exception_ticket" {
  description = "Exception ticket tag value, when applicable."
  type        = string
  default     = ""
}

variable "expires_on" {
  description = "Expiry date tag value, when applicable."
  type        = string
  default     = ""
}

variable "aws_managed_policy_arns" {
  description = "AWS-managed policy ARNs to attach to this group. Must all appear in guardrails/allowed-aws-managed-policies.yaml."
  type        = list(string)
  default     = []
}

variable "custom_policies" {
  description = "Customer-managed policies to create and attach to this group."
  type = list(object({
    name        = string
    policy_json = string
  }))
  default = []
}

variable "members" {
  description = "Names of existing IAM users to add to this group. The users must already exist -- this module does not create them."
  type        = list(string)
  default     = []
}
