#!/bin/bash
# INCY replaces the unscoped default route. More-specific IPv4 halves let
# Tailscale's selected exit node win without deleting INCY's underlay routes.
# Scope: INCY TUN (198.18.0.2), whose helper pins its server/DNS via the uplink.
# Proxy-only needs separate upstream bypass handling; do not install here.
set -u
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
TS=/opt/homebrew/opt/tailscale/bin/tailscale
owned_if=""
owned_routes=""

field() { /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null; }
route_if() { /sbin/route -n get "$1" 2>/dev/null | awk '/interface:/{print $2}'; }
exact_half_if() {
  local dest
  case "$1" in 0.0.0.0/1) dest=0/1 ;; 128.0.0.0/1) dest=128.0/1 ;; *) return 1 ;; esac
  /usr/sbin/netstat -rn -f inet | awk -v dest="$dest" '$1 == dest {print $4; exit}'
}
cleanup() {
  for half in $owned_routes; do
    if [ "$(exact_half_if "$half")" = "$owned_if" ]; then
      /sbin/route -n delete -net "$half" -interface "$owned_if" >/dev/null 2>&1 || true
    fi
  done
  owned_routes=""
  owned_if=""
}
trap 'cleanup; exit 0' TERM INT HUP

last_tick=$(date +%s)
hold_until=0
while true; do
  now=$(date +%s)
  # Ticks are 3 s apart; a long gap means the Mac slept. While the link was
  # down INCY may have lost the host route to its own server, and our /1
  # routes would then send that traffic into Tailscale, whose underlay is
  # INCY: a loop. Drop them now and let both clients settle before re-adding.
  if [ $((now - last_tick)) -gt 30 ]; then
    cleanup
    hold_until=$((now + 20))
    echo "wake detected; split routes held for 20 s"
  fi
  last_tick=$now
  # An unreadable API is not evidence that the user disabled the exit node.
  status=$("$TS" --socket=/var/run/tailscaled.socket status --json 2>/dev/null || true)
  state=$(printf '%s' "$status" | field BackendState || true)
  exit_id=$(printf '%s' "$status" | field ExitNodeStatus.ID || true)
  self_ip=$(printf '%s' "$status" | field Self.TailscaleIPs.0 || true)
  if [ -n "$state" ]; then
    ts_if=""
    if [ -n "$self_ip" ]; then
      for iface in $(/sbin/ifconfig -l); do
        case "$iface" in utun*)
          if /sbin/ifconfig "$iface" | awk -v ip="$self_ip" '$1=="inet" && $2==ip {found=1} END {exit !found}'; then
            ts_if="$iface"
            break
          fi ;;
        esac
      done
    fi
    incy_tun=false
    incy_if=""
    for iface in $(/sbin/ifconfig -l); do
      case "$iface" in utun*)
        if /sbin/ifconfig "$iface" | awk '$1=="inet" && $2=="198.18.0.2" {found=1} END {exit !found}'; then
          incy_tun=true
          incy_if="$iface"
          break
        fi ;;
      esac
    done
    # Both clients remove the shared /0 on teardown. Restore INCY's underlay
    # only when no unscoped default exists; never delete someone else's /0.
    if $incy_tun && [ -z "$(route_if default)" ]; then
      /sbin/route -n add default -interface "$incy_if" >/dev/null 2>&1 || true
    fi
    if [ "$now" -lt "$hold_until" ]; then
      :
    elif [ "$state" = Running ] && [ -n "$exit_id" ] && [ -n "$ts_if" ] && $incy_tun; then
      if [ -n "$owned_if" ] && [ "$owned_if" != "$ts_if" ]; then cleanup; fi
      owned_if="$ts_if"
      for half in 0.0.0.0/1 128.0.0.0/1; do
        existing=$(exact_half_if "$half")
        # Never replace another program's more-specific routes.
        if [ -z "$existing" ]; then
          if /sbin/route -n add -net "$half" -interface "$ts_if" >/dev/null 2>&1; then
            case " $owned_routes " in *" $half "*) ;; *) owned_routes="$owned_routes $half" ;; esac
            echo "installed $half via $ts_if for exit node $exit_id"
          fi
        fi
      done
    else
      cleanup
    fi
  fi
  sleep 3
done
