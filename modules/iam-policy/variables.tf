variable "name" {
  description = "Name of the customer-managed IAM policy."
  type        = string
}

variable "description" {
  description = "Description of the customer-managed IAM policy."
  type        = string
  default     = ""
}

variable "path" {
  description = "IAM path the policy is created under."
  type        = string
  default     = "/org/workloads/"
}

variable "policy_json" {
  description = "Rendered JSON policy document."
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
