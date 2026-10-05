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

variable "slow_seconds" {
  type        = number
  description = "Seconds the slow step takes when trigger_issue is set."
  default     = 240
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

# The culprit. It takes 5 seconds in a healthy run and slow_seconds otherwise.
resource "time_sleep" "database_migration" {
  create_duration = var.trigger_issue ? "${var.slow_seconds}s" : "5s"

  triggers = {
    trigger = terraform_data.trigger.output
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
