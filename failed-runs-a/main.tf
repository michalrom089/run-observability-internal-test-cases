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
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
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

# The culprit. The data source reads during the plan. With trigger_issue set,
# the program exits 1 and the plan fails.
data "external" "image_lookup" {
  program = ["sh", "${path.module}/image-lookup.sh", tostring(var.trigger_issue)]
}

resource "terraform_data" "release" {
  input = data.external.image_lookup.result.image

  triggers_replace = terraform_data.trigger.output
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
