# Installation and removal

This release targets **Apple Silicon macOS 15+**. It is a frontend for the
Homebrew CLI daemon, not a replacement for the official Tailscale GUI app.
The pinned CLI and socket paths are `/opt/homebrew/opt/tailscale/bin/tailscale`
and `/var/run/tailscaled.socket`.

## Install the ordinary setup

1. Install [Homebrew](https://brew.sh/) and Xcode Command Line Tools if needed.
2. Install and start the Homebrew daemon:

   ```sh
   brew install tailscale
   sudo brew services start tailscale
   /opt/homebrew/opt/tailscale/bin/tailscale --socket=/var/run/tailscaled.socket status
   ```

   The final command may report that you are logged out; it should still be
   able to contact the daemon. A separate official Tailscale GUI installation
   can coexist on disk, but it is a **different client**. Avoid running both
   VPN connections at once while diagnosing routes.

3. Download `TailscaleMenuBar-v0.6.0-macos-arm64.zip` and its `.sha256` file
   from [Releases](https://github.com/s1ttt/tailnet-bridge-macos/releases).
   In Terminal, from the download directory:

   ```sh
   shasum -a 256 -c TailscaleMenuBar-v0.6.0-macos-arm64.zip.sha256
   unzip TailscaleMenuBar-v0.6.0-macos-arm64.zip
   ```

4. Move `TailscaleMenuBar.app` to `/Applications` in Finder, then open it.
   The initial launch creates the menu bar icon. Open it again or choose
   **Open Tailnet Bridge** to show the full window. Turn on Tailscale and
   complete the sign-in flow in your browser.

This community binary has an ad-hoc code signature and is **not notarized**.
If Gatekeeper blocks it, inspect the downloaded file and use [Apple's documented
Open Anyway procedure](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).
Do not grant VPN or root permissions to an unexpected app.

## Build instead of using the download

```sh
./build.sh
./TailscaleMenuBar.app/Contents/MacOS/TailscaleMenuBar --self-test
codesign --verify --deep --strict TailscaleMenuBar.app
./install.sh
```

`install.sh` installs **only the interface**. It preserves the previous
`/Applications/TailscaleMenuBar.app` as a dated backup and restarts only the
interface. It does not install or restart `tailscaled` or the route helper.

## Optional bootstrap proxy service

The ordinary Homebrew service does not automatically use the wrapper shipped
here. If your network requires a local HTTP CONNECT bootstrap proxy, review
[`tailscaled-wrapper.sh`](../tailscaled-wrapper.sh) and the
[networking notes](NETWORKING.md) first. Then install it as a separate root
LaunchDaemon. These commands **replace the ordinary Homebrew daemon service**;
run them only when you can tolerate a VPN interruption:

```sh
sudo brew services stop tailscale
sudo install -d -m 755 /usr/local/libexec/tailnet-bridge
sudo install -m 755 tailscaled-wrapper.sh /usr/local/libexec/tailnet-bridge/tailscaled-wrapper.sh
sudo install -m 644 launchd/app.tailnetbridge.tailscaled-wrapper.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/app.tailnetbridge.tailscaled-wrapper.plist
```

The wrapper checks `127.0.0.1` ports `10808`, `10809`, and `10820` every five
seconds. It restarts its child `tailscaled` when the selected listener changes,
so a proxy switch can briefly drop the tailnet. A listening port does not
prove proxy authentication or reachability. Check status before selecting an
exit node:

```sh
/opt/homebrew/opt/tailscale/bin/tailscale --socket=/var/run/tailscaled.socket status
```

## Optional INCY TUN route helper

This helper is **specific to INCY TUN with local interface address
`198.18.0.2`**. Confirm that address and that INCY preserves an underlay route
to its subscription server before installing it. The helper runs as root and
may change IPv4 routes. It is not a general-purpose VPN merger or kill switch.

```sh
sudo install -d -m 755 /usr/local/libexec/tailnet-bridge
sudo install -m 755 tailscale-watchdog.sh /usr/local/libexec/tailnet-bridge/tailscale-watchdog.sh
sudo install -m 644 launchd/app.tailnetbridge.route-watchdog.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/app.tailnetbridge.route-watchdog.plist
```

The helper adds `0.0.0.0/1` and `128.0.0.0/1` through the selected Tailscale
exit node while its exact preconditions hold. After a wake it removes them and
waits 20 s before adding them again. If Wi-Fi is up but the unscoped default
route is missing, it restores the route from the Wi-Fi gateway. If you installed an earlier copy, repeat
the `install` command above and run
`sudo launchctl kickstart -k system/app.tailnetbridge.route-watchdog`. See [Networking](NETWORKING.md)
for limitations and rollback behavior. These commands are examples for a new
installation; do not overlay them on an existing customized launchd setup
without inspecting it first.

## Diagnose and roll back

`bash diagnose-network.sh` is read-only, but its output can reveal device and
IP details. Redact it before posting a bug report. `Quit` in the menu bar
exits only the interface. To remove the UI, quit it and move
`/Applications/TailscaleMenuBar.app` to Trash.

If you installed the optional services, stop them before removing their
scripts. `bootout` sends a termination signal, allowing the route helper to
remove the routes it owns:

```sh
sudo launchctl bootout system /Library/LaunchDaemons/app.tailnetbridge.route-watchdog.plist
sudo launchctl bootout system /Library/LaunchDaemons/app.tailnetbridge.tailscaled-wrapper.plist
```

Move the two `app.tailnetbridge.*.plist` files out of
`/Library/LaunchDaemons` so they will not load at the next boot, then start
the ordinary service again with `sudo brew services start tailscale`.
Verify the route table and daemon status before assuming network access is
restored. If you never installed the optional services, skip this step.
