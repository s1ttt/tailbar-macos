#!/bin/bash
# tailscaled reads HTTP(S)_PROXY only when the process starts. The bootstrap
# proxy can appear after this LaunchDaemon starts or move between clients, so
# keep the wrapper alive and restart only the child daemon when its endpoint
# changes.
#
# INCY exposes a mixed HTTP/SOCKS listener on :10808 when it runs in
# "Only proxy" mode. Happ uses :10809 or :10820. All three are usable as an
# HTTP CONNECT proxy for tailscaled's control-plane and DERP traffic.

set -u

TAILSCALED=/opt/homebrew/opt/tailscale/bin/tailscaled
child_pid=""
active_proxy=""

bootstrap_proxy() {
  for port in 10808 10809 10820; do
    if nc -z -w1 127.0.0.1 "$port" 2>/dev/null; then
      printf 'http://127.0.0.1:%s' "$port"
      return 0
    fi
  done
  return 1
}

stop_child() {
  if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
    kill "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
  child_pid=""
}

trap 'stop_child; exit 0' TERM INT HUP

while true; do
  proxy="$(bootstrap_proxy || true)"

  if [ "$proxy" != "$active_proxy" ] || [ -z "$child_pid" ] || ! kill -0 "$child_pid" 2>/dev/null; then
    stop_child

    if [ -n "$proxy" ]; then
      export HTTP_PROXY="$proxy"
      export HTTPS_PROXY="$proxy"
    else
      unset HTTP_PROXY HTTPS_PROXY
    fi

    "$TAILSCALED" &
    child_pid=$!
    active_proxy="$proxy"
  fi

  sleep 5
done
