#!/bin/sh
# Usage: sh create-bucket.sh <name> <trigger_issue>
#
# The local-exec provisioner of a culprit resource runs this during the apply.
# It prints the bucket in a healthy run and exits 1 otherwise.
set -eu

if [ "$2" = "true" ]; then
  echo "$1: AccessDenied: not authorized to perform s3:CreateBucket" >&2
  exit 1
fi

echo "$1: created"
