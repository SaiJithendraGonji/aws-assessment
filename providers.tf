provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project    = "unleash-live-assessment"
      ManagedBy  = "terraform"
      Owner      = "sjgsetty@gmail.com"
      Repository = "https://github.com/SaiJithendraGonji/aws-assessment"
    }
  }
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project    = "unleash-live-assessment"
      ManagedBy  = "terraform"
      Owner      = "sjgsetty@gmail.com"
      Repository = "https://github.com/SaiJithendraGonji/aws-assessment"
    }
  }
}

provider "aws" {
  alias   = "eu_west_1"
  region  = "eu-west-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project    = "unleash-live-assessment"
      ManagedBy  = "terraform"
      Owner      = "sjgsetty@gmail.com"
      Repository = "https://github.com/SaiJithendraGonji/aws-assessment"
    }
  }
}