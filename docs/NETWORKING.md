# Networking model and limitations

Tailnet Bridge talks only to a Homebrew `tailscaled` through the pinned local
socket. The app can start or stop Tailscale, select an exit node, and display
status. It does not implement VLESS, Trojan, SOCKS, a TUN interface, or routing
itself. Those functions belong to separately installed software.

## Three modes

| Mode | Bootstrap path | What the app does |
| --- | --- | --- |
| Ordinary network | Direct `tailscaled` access | Allows connection without a local proxy. |
| INCY/Happ local listener | Optional wrapper sets `HTTP_PROXY`/`HTTPS_PROXY` for `tailscaled` on startup | Shows listener status. The wrapper, if installed, chooses 10808, 10809, then 10820. |
| INCY TUN + exit node | INCY supplies the underlay; optional root route helper adds two IPv4 `/1` routes through Tailscale | Displays Tailscale and exit-node state. |

The dot in the menu bar reports **process/listener state**, not successful
end-to-end traffic. Amber means an INCY/Happ app is running without a detected
listener; green means a TCP listener responded locally. A background listener
may exist even when neither GUI is open. The permanent green Dock dot is only
an identity mark.

## Why the INCY TUN helper exists

An INCY TUN can own the ordinary default route even when Tailscale reports a
selected exit node. Reachable tailnet/subnet devices do not prove that public
traffic uses the exit node. When the exact INCY TUN address `198.18.0.2`, a
running Tailscale interface, and a selected exit node are all present, the
helper adds `0.0.0.0/1` and `128.0.0.0/1` via Tailscale. These two routes are
more specific than an ordinary IPv4 default route. It avoids replacing routes
another program already owns and cleans up routes it created on a normal stop.

This behavior is **IPv4 only**. It does not establish IPv6 or DNS routing,
prevent leaks, guarantee a working exit node, or act as a kill switch. It also
depends on INCY preserving specific underlay routes to its own server/DNS.
Different INCY versions or other VPN clients may behave differently. An
abrupt crash can leave the helper's routes behind because route ownership is
kept in memory; check `netstat -rn -f inet` before repairing routes manually.

## Sleep and wake

With INCY or Happ set to keep the VPN on while the Mac sleeps, a running
Tailscale does not survive a lid close on its own. While Wi-Fi is down the
client can lose the host route to its own server; after wake that traffic
follows the helper's `/1` routes into Tailscale, whose underlay is the client
itself. The result is a loop that previously needed every app quit and Wi-Fi
toggled.

Tailnet Bridge now repeats that manual fix automatically (**Settings → Sleep
and wake**, on by default):

1. Before sleep, if Tailscale is connected, the app runs `tailscale down` and
   holds sleep for a few seconds until the route helper has removed its `/1`
   routes. INCY/Happ are left running.
2. After a full wake, it waits (up to 45 s) for a Wi-Fi/Ethernet default
   route and for the INCY TUN or local proxy that existed before sleep.
3. It runs `tailscale up`. `down` keeps preferences, so the exit node is kept;
   if a plain `up` fails it falls back to `up --reset` and restores
   preferences as the Connect button does.
4. It waits for `Running` and, with an exit node selected, a `tailscale ping`
   to it. If either fails, it cycles once more and then notifies you.

The same cycle is available at any time as **Reconnect Tailscale** in the menu
bar menu and in Settings. If you quit the app or it is not running during
sleep, nothing is stopped or restarted. The route helper also detects a wake
on its own (a long gap between its 3-second polls): it drops its `/1` routes
at once and waits 20 s before adding them again.

## Why the wrapper is separate

`tailscaled` reads `HTTP_PROXY` and `HTTPS_PROXY` when it starts. The wrapper
polls local listener ports, launches the child daemon with proxy variables
when one is available, and starts it without those variables otherwise. A
change of listener restarts only that child. The app's own port indicator does
not configure a plain Homebrew service; install the wrapper only if your
network requires it.

These ports are treated as HTTP CONNECT listeners. A port scan cannot verify
CONNECT, credentials, TLS, or the subscription server. Some networks still
need INCY in TUN mode. The wrapper and route helper may be used separately:
one handles daemon bootstrap, the other handles IPv4 route priority.

## Read-only checks

```sh
/opt/homebrew/opt/tailscale/bin/tailscale --socket=/var/run/tailscaled.socket status
netstat -rn -f inet
route -n get 203.0.113.1
bash diagnose-network.sh
```

`203.0.113.1` is a documentation-only test address. Route lookup shows the
chosen interface, not packet delivery or a public IP. The diagnostic output
may include real account, device, and IP data: redact it before sharing.

For the official exit-node feature, see
[Tailscale's documentation](https://tailscale.com/docs/features/exit-nodes).
