#!/bin/sh
# Usage: sh ../hooks/provider-findings.sh <pin|conflict>
#
# In a healthy run it does nothing. In a run that sets
# TF_VAR_trigger_issue=true:
#
#   pin       runs before init. It pins hashicorp/random to an older version
#             than the healthy runs resolve, so the version changes between
#             runs: ProviderVersionChange.
#   conflict  runs after init. It installs hashicorp/random again in pinned/,
#             at a third version, so one run resolves two versions:
#             ProviderVersionConflict.
set -eu

mode=$1

if [ "${TF_VAR_trigger_issue:-false}" != "true" ]; then
  echo "provider-findings: healthy run, nothing to do"
  exit 0
fi

case "$mode" in
pin)
  # An override file, because a module takes only one required_providers
  # block. Override files merge their entries into it.
  cat >random_override.tf <<'TF'
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "= 3.6.3"
    }
  }
}
TF
  echo "provider-findings: pinned hashicorp/random to 3.6.3"
  ;;
conflict)
  tofu -chdir=pinned init -input=false
  ;;
*)
  echo "provider-findings: unknown mode ${mode}" >&2
  exit 2
  ;;
esac
