# Contributing

This is an independent community project. Please open an issue before a large
change, especially anything that changes routes, DNS, launchd services, or the
`tailscaled` process lifecycle.

## Local checks

On Apple Silicon macOS 15 or later:

```sh
./build.sh
./TailscaleMenuBar.app/Contents/MacOS/TailscaleMenuBar --self-test
codesign --verify --deep --strict TailscaleMenuBar.app
```

Self-tests do not connect to a tailnet or modify VPN settings. Test network
changes separately on a machine where temporary loss of connectivity is safe.

## Privacy before submitting

Do not include real account names, tailnet names, device IDs, auth URLs,
subscription URLs, proxy credentials, IP addresses, `tailscale status --json`
output, route dumps, or screenshots of a live network. Use synthetic examples.
The repository ignores the original author's local working notes; please keep
your own diagnostics outside Git as well.

By contributing, you agree to license your contribution under BSD-3-Clause.
