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
  }
}

# The run environment sets this. The first runs of a stack leave it alone.
variable "trigger_issue" {
  type        = bool
  description = "Makes this run misbehave the way the case describes."
  default     = false
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

# The culprits. The three steps do not depend on each other, so the apply
# starts them together. With trigger_issue set, every provisioner exits 1 and
# the apply reports three failed resources.
locals {
  deploy_steps = toset(["migrate_schema", "warm_cache", "publish_release"])
}

resource "terraform_data" "deploy_step" {
  for_each = local.deploy_steps

  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "sh ${path.module}/deploy-step.sh ${each.key} ${var.trigger_issue}"
  }
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
