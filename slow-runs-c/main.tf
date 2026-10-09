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

# The timestamp forces replacement on every apply, so every run has work to do.
resource "terraform_data" "trigger" {
  input = timestamp()
}

# The decoys. Every case has them.
module "workload" {
  source = "../modules/workload"

  trigger = terraform_data.trigger.output
}

# The culprit is init. The before_init hook adds three large providers, and
# the after_init hook removes them again, so plan and apply stay fast.
# See hooks/add-providers.sh.

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
