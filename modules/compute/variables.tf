variable "region" {
  description = "AWS region this compute stack is deployed into"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID from the auth module"
  type        = string
}

variable "cognito_user_pool_endpoint" {
  description = "Cognito JWT issuer URL"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "Cognito App Client ID for the JWT authorizer audience"
  type        = string
}

variable "candidate_email" {
  description = "Candidate email embedded in SNS verification payloads"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL embedded in SNS verification payloads"
  type        = string
}

variable "sns_verification_topic_arn" {
  description = "Unleash Live candidate verification SNS topic ARN (cross-account)"
  type        = string
  default     = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
}

variable "vpc_cidr" {
  description = "CIDR block for the compute VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "lambda_runtime" {
  description = "Lambda runtime for both functions"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "fargate_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}
