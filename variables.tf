variable "aws_profile" {
  description = "AWS CLI profile name, null for CI workflow"
  type        = string
  default     = null
}

variable "candidate_email" {
  description = "Email - embedded in Cognito test user and SNS payloads"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL - embedded in SNS verification payloads"
  type        = string
  default     = "https://github.com/SaiJithendraGonji/aws-assessment"
}

variable "cognito_password_secret" {
  description = "Secret name for the Cognito test user password"
  type        = string
  default     = "unleash-live/cognito-test-user-password"
}