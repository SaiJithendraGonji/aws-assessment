data "aws_secretsmanager_secret_version" "cognito_password" {
  secret_id = var.cognito_password_secret
}

module "auth" {
  source = "./modules/auth"

  providers = {
    aws = aws
  }

  email            = var.candidate_email
  cognito_password = data.aws_secretsmanager_secret_version.cognito_password.secret_string
}

module "compute_us_east_1" {
  source = "./modules/compute"

  providers = {
    aws = aws.us_east_1
  }

  region                      = "us-east-1"
  cognito_user_pool_id        = module.auth.user_pool_id
  cognito_user_pool_endpoint  = module.auth.user_pool_endpoint
  cognito_user_pool_client_id = module.auth.client_id
  candidate_email             = var.candidate_email
  github_repo                 = var.github_repo
  vpc_cidr                    = "10.0.0.0/16"
  public_subnet_cidrs         = ["10.0.1.0/24", "10.0.2.0/24"]
}

module "compute_eu_west_1" {
  source = "./modules/compute"

  providers = {
    aws = aws.eu_west_1
  }

  region                      = "eu-west-1"
  cognito_user_pool_id        = module.auth.user_pool_id
  cognito_user_pool_endpoint  = module.auth.user_pool_endpoint
  cognito_user_pool_client_id = module.auth.client_id
  candidate_email             = var.candidate_email
  github_repo                 = var.github_repo
  vpc_cidr                    = "10.1.0.0/16"
  public_subnet_cidrs         = ["10.1.1.0/24", "10.1.2.0/24"]
}