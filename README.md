# Unleash Live - AWS DevOps Assessment

Multi-region AWS infrastructure provisioned with Terraform. Deploys an authenticated API backend across `us-east-1` and `eu-west-1`, backed by Lambda, DynamoDB, and ECS Fargate - secured by a single Cognito User Pool.

## Architecture

```
                    +----------------------------------+
                    |  Cognito User Pool (us-east-1)   |
                    |  Single source of truth for JWT  |
                    +----------------+-----------------+
                                     |
              +----------------------+----------------------+
              |                                            |
   +----------+----------+                   +------------+----------+
   |   us-east-1 Stack   |                   |   eu-west-1 Stack     |
   |                     |                   |                       |
   |  API Gateway (HTTP) |                   |  API Gateway (HTTP)   |
   |  +- GET /greet      |                   |  +- GET /greet        |
   |  +- POST /dispatch  |                   |  +- POST /dispatch    |
   |                     |                   |                       |
   |  Lambda (Greeter)   |                   |  Lambda (Greeter)     |
   |  +-> DynamoDB       |                   |  +-> DynamoDB         |
   |  +-> SNS (verify)   |                   |  +-> SNS (verify)     |
   |                     |                   |                       |
   |  Lambda (Dispatcher)|                   |  Lambda (Dispatcher)  |
   |  +-> ECS RunTask    |                   |  +-> ECS RunTask      |
   |                     |                   |                       |
   |  ECS Fargate        |                   |  ECS Fargate          |
   |  +-> SNS (verify)   |                   |  +-> SNS (verify)     |
   +---------------------+                   +-----------------------+
```

Both stacks publish SNS verification messages to:
`arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic`

JWT validation works cross-region because Cognito's JWKS endpoint is a public HTTPS URL - API Gateway calls it directly with no dependency on us-east-1 being reachable from eu-west-1.

## Repository Structure

```
aws-assessment/
├── .github/workflows/
│   ├── terraform-plan.yml       # Runs on PR to main: lint, security scan, plan
│   └── terraform-apply.yml      # Runs on push to main: approval gate, apply, integration tests
├── modules/
│   ├── auth/                    # Cognito User Pool - us-east-1 only
│   └── compute/                 # Regional stack - instantiated twice
│       ├── apigw.tf
│       ├── dynamodb.tf
│       ├── ecs.tf
│       ├── lambda.tf
│       ├── networking.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── lambda/
│           ├── greeter/index.py
│           └── dispatcher/index.py
├── scripts/
│   └── test_deployment.py
├── main.tf
├── providers.tf
├── versions.tf
├── backend.tf
├── variables.tf
└── outputs.tf
```

## Multi-Region Design

The `compute` module is called twice from `main.tf` with different provider aliases:

```hcl
module "compute_us_east_1" {
  source    = "./modules/compute"
  providers = { aws = aws.us_east_1 }
  region    = "us-east-1"
}

module "compute_eu_west_1" {
  source    = "./modules/compute"
  providers = { aws = aws.eu_west_1 }
  region    = "eu-west-1"
}
```

## Prerequisites

- Terraform 1.14.6
- AWS CLI with a profile that has sufficient IAM permissions
- Python 3.12+ with `boto3` and `requests`
- S3 bucket `unleash-live-assessment-tfstate` in us-east-1 (versioning and SSE enabled)
- Cognito test user password stored in AWS Secrets Manager under `unleash-live/cognito-test-user-password`

## Local Deployment

```bash
export AWS_PROFILE=Devops-admin

terraform init
terraform fmt --recursive
terraform validate
terraform plan
terraform apply
```

## Running the Test Script

```bash
pip install boto3 requests
```

Option A - reads Terraform outputs automatically, prompts for password:

```bash
python scripts/test_deployment.py --from-tf-output
```

Option B - pass everything explicitly:

```bash
python scripts/test_deployment.py \
  --user-pool-id <pool_id> \
  --client-id <client_id> \
  --email <email> \
  --password <password> \
  --api-us-east-1 https://<id>.execute-api.us-east-1.amazonaws.com \
  --api-eu-west-1 https://<id>.execute-api.eu-west-1.amazonaws.com
```

The script runs `/greet` and `/dispatch` concurrently across both regions and validates that each endpoint returns HTTP 200 and the correct region in the response body.

## Tear Down

```bash
terraform destroy
```

## CI/CD Pipeline

GitHub Actions workflows use OIDC to assume an IAM role - no long-lived credentials.

| Workflow | Trigger | Jobs |
|---|---|---|
| terraform-plan.yml | PR to main | lint-validate → security-scan → plan (posts summary to PR) |
| terraform-apply.yml | Push to main | await-approval → apply → integration-tests |

The `await-approval` job is gated by the `production` GitHub Environment. A required reviewer must approve before apply runs.