#!/bin/sh
# Usage: sh ../hooks/step.sh <name> <seconds> [slow|fail]
#
# A hook that does nothing but take time. In a healthy run it sleeps <seconds>.
# The third argument says what the hook does in a run that sets
# TF_VAR_trigger_issue=true:
#
#   slow  sleeps TF_VAR_slow_seconds instead.
#   fail  exits 1 after its sleep.
#
# Without a third argument the hook acts the same in every run.
set -eu

name=$1
seconds=$2
issue=${3:-}

if [ "${TF_VAR_trigger_issue:-false}" = "true" ] && [ "$issue" = "slow" ]; then
  seconds=${TF_VAR_slow_seconds:-240}
fi

echo "${name}: sleeping ${seconds} seconds"
sleep "${seconds}"

if [ "${TF_VAR_trigger_issue:-false}" = "true" ] && [ "$issue" = "fail" ]; then
  echo "${name}: configuration check failed" >&2
  exit 1
fi
