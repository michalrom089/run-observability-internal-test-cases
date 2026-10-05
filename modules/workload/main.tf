terraform {
  required_providers {
    time = {
      source = "hashicorp/time"
    }
  }
}

variable "trigger" {
  type        = string
  description = "Changes on every run, so every resource is replaced on every run."
}

# The decoys. Every case has the same six steps, so the slowest resource lists
# look alike until one case misbehaves.
locals {
  steps = {
    network = "2s"
    iam     = "1s"
    storage = "3s"
    cache   = "2s"
    queue   = "1s"
    dns     = "2s"
  }
}

resource "time_sleep" "step" {
  for_each = local.steps

  create_duration = each.value

  triggers = {
    trigger = var.trigger
  }
}
