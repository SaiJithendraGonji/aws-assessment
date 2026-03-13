terraform {
  backend "s3" {
    bucket       = "unleash-live-assessment-tfstate"
    key          = "global/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
