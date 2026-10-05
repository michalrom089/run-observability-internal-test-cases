#!/bin/sh
# Usage: sh image-lookup.sh <trigger_issue>
#
# The external data source runs this during the plan. It prints a JSON object
# in a healthy run and exits 1 otherwise.
set -eu

if [ "$1" = "true" ]; then
  echo "image-lookup: no image matches tag release-2026" >&2
  exit 1
fi

echo '{"image": "registry.example.com/app:release-2026"}'
