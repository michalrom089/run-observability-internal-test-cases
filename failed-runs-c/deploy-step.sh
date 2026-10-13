#!/bin/sh
# Usage: sh deploy-step.sh <name> <trigger_issue>
#
# The local-exec provisioner of a culprit resource runs this during the apply.
# It prints the step in a healthy run and exits 1 otherwise.
set -eu

if [ "$2" = "true" ]; then
  echo "$1: the deploy endpoint returned 503" >&2
  exit 1
fi

echo "$1: done"
