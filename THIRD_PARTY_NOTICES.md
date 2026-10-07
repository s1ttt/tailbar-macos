# Third-party notices

Tailbar contains no third-party source code, images or other assets. Its menu
bar glyph (`TailbarGlyph` in `Sources/main.swift`) and its Dock icon
(`Resources/GenerateAppIcon.swift`) are drawn in code for this project. At
runtime the app runs the separately installed Homebrew `tailscale` command-line
tool and the macOS system tools `netstat`, `ifconfig`, `route`, `scutil`,
`networksetup`, `nc` and `curl`. It does not load or read any other
application.

Tailscale is a trademark of Tailscale Inc. INCY and Happ are products of their
respective owners. These names are used only to identify compatibility.
Tailbar is an independent project and is not affiliated with, sponsored by, or
endorsed by any of them.
