#!/bin/bash
# Read-only local diagnostics. No external requests or network mutations.
set -u
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

section() { printf '\n### %s\n' "$1"; }
section 'Time'
date

section 'LaunchDaemons'
for service in app.tailnetbridge.route-watchdog app.tailnetbridge.tailscaled-wrapper homebrew.mxcl.tailscale; do
  printf '%s\n' "$service"
  launchctl print "system/$service" 2>&1 |
    awk '/state =|program =|pid =|last exit code|Could not find service|not permitted/'
done

section 'Local TCP proxy listeners (not a CONNECT health check)'
for port in 10808 10809 10820; do
  if nc -z -w1 127.0.0.1 "$port" 2>/dev/null; then
    printf '%s open\n' "$port"
  else
    printf '%s closed or unreachable\n' "$port"
  fi
done

section 'IPv4 routes'
netstat -rn -f inet
section 'Route lookups only; no packets sent'
for destination in 1.1.1.2 203.0.113.1; do
  route -n get "$destination" 2>&1
done

section 'Tailscale status (10-second deadline)'
TS=/opt/homebrew/opt/tailscale/bin/tailscale
if [ -x "$TS" ]; then
  # Only the diagnostic CLI is terminated on timeout, never tailscaled.
  (
    "$TS" --socket=/var/run/tailscaled.socket status --json &
    diagnostic_pid=$!
    (
      sleep 10
      kill -TERM "$diagnostic_pid" 2>/dev/null || true
    ) &
    timer_pid=$!
    wait "$diagnostic_pid"
    diagnostic_rc=$?
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
    exit "$diagnostic_rc"
  ) | plutil -extract ExitNodeStatus json -o - - 2>/dev/null ||
    printf 'ExitNodeStatus unavailable (no selected exit node, API error, or timeout).\n'
else
  printf 'Tailscale CLI not found at %s\n' "$TS"
fi

section 'Recent watchdog log (entries may be from previous sessions)'
tail -n 12 /var/log/tailnet-bridge-route-watchdog.log 2>&1
