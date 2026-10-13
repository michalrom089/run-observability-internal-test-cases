# Usage: . ../hooks/throttle.sh <start|stop>
#
# Source this file, do not run it with sh. Spacelift runs the hooks and
# tofu init in one shell, so only a sourced file can export HTTPS_PROXY to
# init. For the same reason the file uses return, not exit, and no set -eu:
# both would act on the Spacelift shell.
#
#   start  runs before init. In a healthy run it does nothing. In a run that
#          sets TF_VAR_trigger_issue=true it starts hooks/throttle-proxy.py
#          and exports HTTPS_PROXY, so init downloads the providers at
#          THROTTLE_BYTES_PER_SECOND.
#   stop   runs after init, in every run. It stops the proxy and unsets
#          HTTPS_PROXY, so plan and apply do not use it.

throttle_mode=$1
throttle_port=18080
throttle_bytes_per_second=${THROTTLE_BYTES_PER_SECOND:-1048576}
throttle_pid_file=/tmp/throttle-proxy.pid
throttle_ready_file=/tmp/throttle-proxy.ready

if [ "$throttle_mode" = "start" ] && [ "${TF_VAR_trigger_issue:-false}" != "true" ]; then
  echo "throttle: healthy run, no proxy"
  return 0
fi

case "$throttle_mode" in
start)
  rm -f "$throttle_ready_file"
  python3 ../hooks/throttle-proxy.py "$throttle_port" "$throttle_bytes_per_second" "$throttle_ready_file" \
    >/tmp/throttle-proxy.log 2>&1 &
  echo $! >"$throttle_pid_file"

  throttle_waited=0
  while [ ! -f "$throttle_ready_file" ]; do
    if [ "$throttle_waited" -ge 10 ]; then
      echo "throttle: proxy did not start" >&2
      cat /tmp/throttle-proxy.log >&2
      return 1
    fi
    sleep 1
    throttle_waited=$((throttle_waited + 1))
  done

  export HTTPS_PROXY="http://127.0.0.1:${throttle_port}"
  echo "throttle: provider downloads limited to ${throttle_bytes_per_second} bytes per second"
  ;;
stop)
  if [ -f "$throttle_pid_file" ]; then
    kill "$(cat "$throttle_pid_file")" 2>/dev/null
    rm -f "$throttle_pid_file" "$throttle_ready_file"
  fi
  unset HTTPS_PROXY
  echo "throttle: proxy stopped"
  ;;
*)
  echo "throttle: unknown mode ${throttle_mode}" >&2
  return 2
  ;;
esac
