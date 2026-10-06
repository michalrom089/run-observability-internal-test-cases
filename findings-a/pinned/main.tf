# Not a module of the case. In an issue run, a hook runs
# `tofu -chdir=pinned init` to install a second hashicorp/random version.
# Nothing plans or applies this directory.
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "= 3.5.1"
    }
  }
}
