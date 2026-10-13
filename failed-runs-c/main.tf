terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# The run environment sets this. The first runs of a stack leave it alone.
variable "trigger_issue" {
  type        = bool
  description = "Makes this run misbehave the way the case describes."
  default     = false
}

# Fake static keys and no calls at configure time, so the plan passes. Every
# bucket then fails in the apply, because S3 rejects the keys. The static keys
# also keep the SDK off the worker's instance role.
provider "aws" {
  region     = "eu-west-1"
  access_key = "AKIARUNOBSERVABILITY"
  secret_key = "run-observability-internal-test-cases"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  max_retries                 = 0
}

# The timestamp forces replacement on every apply, so every run has work to do.
resource "terraform_data" "trigger" {
  input = timestamp()
}

# The decoys. Every case has them.
module "workload" {
  source = "../modules/workload"

  trigger = terraform_data.trigger.output
}

# The culprits. The healthy runs have no bucket. The issue run adds three, and
# they do not depend on each other, so the apply starts them together and
# reports three failed resources.
locals {
  buckets = toset(["assets", "logs", "backups"])
}

resource "aws_s3_bucket" "bucket" {
  for_each = var.trigger_issue ? local.buckets : []

  bucket_prefix = "run-obs-${each.key}-"
}

resource "random_id" "output" {
  byte_length = 7

  keepers = {
    trigger = terraform_data.trigger.id
  }
}

output "random_id" {
  value       = random_id.output.hex
  description = "Random ID that changes on every apply."
}
