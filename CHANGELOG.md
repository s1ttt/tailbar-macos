# Changelog

## 0.5.0 — first public preview

- macOS menu bar and window interface for a separate Homebrew `tailscaled` daemon.
- Device list, search, exit-node controls, connection status, diagnostics, and preferences.
- Automatic local proxy detection for INCY/Happ listeners on ports 10808, 10809, and 10820.
- Top-left status dot: amber when the client app is running without a local listener;
  green when a local listener is available. The Dock icon has a permanent green
  identity dot.
- Optional bootstrap wrapper and IPv4 INCY TUN route helper are included as
  advanced, separately installed scripts.
- Quit closes the interface while leaving the daemon running.

This is a preview for Apple Silicon macOS 15+. The binary is ad-hoc signed,
not notarized. See [installation](docs/INSTALL.md) and [networking limitations](docs/NETWORKING.md).
