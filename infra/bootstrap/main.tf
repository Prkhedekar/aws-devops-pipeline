# One-time setup: creates the S3 bucket that stores Terraform state for every environment.
# This folder keeps its own state locally (chicken-and-egg: the bucket can't store its own creation).
#
#   cd infra/bootstrap
#   terraform init
#   terraform apply -var="state_bucket_name=<globally-unique-name>"

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "ap-south-1" # Mumbai
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name, e.g. yourname-tfstate-7f3k"
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true # losing state = losing track of your infrastructure
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled" # lets you recover a corrupted/overwritten state file
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}
