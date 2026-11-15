terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in the bucket created by infra/bootstrap.
  # Bucket and region come from backend.hcl:  terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3-native state locking (Terraform >= 1.10), no DynamoDB table needed
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "aws-devops-pipeline"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
