# Networking model and limitations

Tailbar talks only to a Homebrew `tailscaled` through the pinned local
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
follows the exit node's `0/1` and `128.0/1` routes (installed by `tailscaled`
itself, or by the route helper) into Tailscale, whose underlay is the client
itself. The result is a loop that previously needed every app quit and Wi-Fi
toggled.

Tailbar now repeats that manual fix automatically (**Settings → Sleep
and wake**, on by default):

1. Before sleep, if Tailscale is connected, the app runs `tailscale down` and
   holds sleep for a few seconds until the `/1` routes are gone. INCY/Happ are
   left running.
2. After a full wake, it waits for a Wi-Fi/Ethernet default route with no time
   limit (a phone hotspot may need joining by hand; the menu says so), then
   up to 45 s for the INCY TUN or local proxy that existed before sleep.
   Connecting by hand meanwhile cancels the automatic reconnect.
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

## Network health and repair

Sleep is not the only way to end up with Wi-Fi connected but no internet.
Moving from a phone hotspot to home Wi-Fi, quitting INCY/Happ, or turning an
exit node off can leave the Mac with:

- no unscoped default route, although Wi-Fi has a gateway (both clients and
  Tailscale's exit-node teardown remove the shared `/0`);
- a default or `/1` route into a tunnel interface that has lost its address;
- DNS still pointing at INCY's `198.18.x` resolver after INCY stopped, or at
  Tailscale's `100.100.100.100` after Tailscale stopped;
- routes and DNS that look fine while nothing answers: the exit node is stuck,
  or the path is broken in a way local checks cannot see.

Every 20 s, and 5 s after INCY/Happ start or quit, the app checks routes and
DNS locally. At most once a minute it also checks internet reachability with
an HTTP request to `http://captive.apple.com/hotspot-detect.html`, the URL
macOS itself uses. Any HTTP answer counts as reachable, a captive portal
included. If the internet check fails while an exit node is selected, it pings
the exit node over the tailnet.

A problem has to show up on two checks at least 10 s apart. Then the app
repairs it (**Settings → Detect and repair a broken network automatically**,
on by default):

- **Only the exit node is stuck:** the Reconnect Tailscale cycle.
- **Anything else:** what used to be done by hand. Stop Tailscale, turn Wi-Fi
  off and on (only when Wi-Fi is the uplink), wait for Wi-Fi and INCY/Happ,
  then restore Tailscale with the same exit node. If Wi-Fi does not rejoin
  within 60 s (a phone hotspot often does not), the app waits for it as it
  does after sleep.

There are at most two automatic attempts, two minutes apart. After that the
app posts one "Network still broken" notification and waits until the network
is healthy again. **Repair Network** in the menu bar menu, Settings, and
Diagnostics runs the full repair on demand, without those limits. The current
verdict appears in Diagnostics and, when there is a problem, in the menu,
where clicking it starts a repair.

The app cannot change routes itself. With the INCY TUN route helper
installed, a missing default route is also restored within about 3 s, as
root, from the Wi-Fi gateway, before the app would restart Wi-Fi.

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
