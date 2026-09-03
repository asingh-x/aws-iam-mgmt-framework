variable "name" {
  description = "Name of the legacy IAM user."
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
  description = "Security exception ticket authorizing this legacy IAM user."
  type        = string
}

variable "expires_on" {
  description = "Date (YYYY-MM-DD) this exception expires."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "ARN of the mandatory permissions boundary policy to attach to this user."
  type        = string
}

variable "custom_policy_name" {
  description = "Name of the customer-managed policy created for this user."
  type        = string
}

variable "custom_policy_json" {
  description = "Rendered JSON policy document granting this user's application permissions."
  type        = string
}
