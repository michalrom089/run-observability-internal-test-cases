#!/bin/sh
# Usage: sh ../hooks/add-providers.sh <slow|fail>
#
# The stack runs this before init. In a healthy run it does nothing. In a run
# that sets TF_VAR_trigger_issue=true it writes extra_providers_override.tf, so
# init has more providers to install:
#
#   slow  three large providers from the public registry.
#   fail  a provider from a registry host that does not resolve.
#
# An override file, because a module takes only one required_providers block.
# Override files merge their entries into it. No resource uses these
# providers, so the plan needs no credentials.
set -eu

mode=$1

if [ "${TF_VAR_trigger_issue:-false}" != "true" ]; then
  echo "add-providers: healthy run, no extra providers"
  exit 0
fi

case "$mode" in
slow)
  cat >extra_providers_override.tf <<'TF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
TF
  ;;
fail)
  # .invalid never resolves (RFC 2606), so the download always fails.
  cat >extra_providers_override.tf <<'TF'
terraform {
  required_providers {
    platform = {
      source  = "registry.acme.invalid/acme/platform"
      version = "~> 1.0"
    }
  }
}
TF
  ;;
*)
  echo "add-providers: unknown mode ${mode}" >&2
  exit 2
  ;;
esac

echo "add-providers: wrote extra_providers_override.tf (${mode})"
