variable "name" {
  description = "Name of the IAM role."
  type        = string
}

variable "owner" {
  description = "Owner tag value (team or individual email)."
  type        = string
}

variable "application" {
  description = "Application tag value."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment tag value."
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

variable "trust_service_principal" {
  description = "AWS service principal allowed to assume this role, e.g. lambda.amazonaws.com."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "ARN of the mandatory permissions boundary policy to attach to this role."
  type        = string
}

variable "aws_managed_policy_arns" {
  description = "AWS-managed policy ARNs to attach to this role. Must all appear in guardrails/allowed-aws-managed-policies.yaml."
  type        = list(string)
  default     = []
}

variable "custom_policies" {
  description = "Customer-managed policies to create and attach to this role."
  type = list(object({
    name        = string
    policy_json = string
  }))
  default = []
}

variable "create_instance_profile" {
  description = "Whether to create an EC2 instance profile for this role."
  type        = bool
  default     = false
}
