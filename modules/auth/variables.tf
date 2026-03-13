variable "email" {
  description = "Email address for the Cognito test user"
  type        = string
}

variable "cognito_password" {
  description = "Permanent password for the Cognito test user"
  type        = string
  sensitive   = true
}
