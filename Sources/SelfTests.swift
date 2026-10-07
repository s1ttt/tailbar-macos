import AppKit

func runInterfaceSelfTests() {
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
        print("PASS: \(message)")
    }
    let sample = Data("{\n\t\"State\":5,\"nested\":{\"text\":\"} { \\\" Привет\"}\n}\n{\"State\":6}\n".utf8)
    var parser = JSONObjectStream()
    var events: [[String: Any]] = []
    for byte in sample { events += parser.feed(Data([byte])) }
    check(events.count == 2, "fragmented JSON and UTF-8, nested objects, escaped quotes")
    check(events.first?["State"] as? Int == 5 && events.last?["State"] as? Int == 6, "Starting → Running order preserved")
    check(parser.feed(Data("{}\n{}\n".utf8)).count == 2, "coalesced empty events")
    check(parser.feed(Data(" \n".utf8)).isEmpty, "whitespace is ignored")
    let icons = NativeStatusIcons()
    let names = ["StatusBarIcon", "StatusBarIconDimmed", "StatusBarIconDefaultRouterOnline",
                 "StatusBarIconDefaultRouterOffline", "StatusBarIconErrorOnline", "StatusBarIconErrorOffline"]
    if Bundle(path: "/Applications/Tailscale.app") != nil {
        for name in names {
            check(icons.image(name)?.tiffRepresentation != nil, "macOS asset: \(name)")
        }
        check(icons.hasAnimation, "all 16 original macOS animation frames available")
        let a = icons.image("StatusBarIcon")!
        a.size = NSSize(width: 100, height: 100)
        check(icons.image("StatusBarIcon")!.size.width == 22, "native 22pt canvas preserved; cached assets are copied")
    }
    let delegate = AppDelegate()
    for state in [AppDelegate.MatrixState.dim, .connected, .exitNode(online: true), .exitNode(online: false), .wave(frame: 15)] {
        check(delegate.matrixIcon(state).tiffRepresentation != nil, "status icon renders")
    }
    check(delegate.animationTimer == nil, "no animation while idle")
    delegate.nativeIcons = NativeStatusIcons(path: "/nonexistent/Tailscale.app")
    check(!delegate.nativeIcons.hasAnimation, "missing original app uses fallback")
    check(delegate.matrixIcon(.wave(frame: 16)).tiffRepresentation != nil, "fallback animation renders without original app")
    let fixture = Data(#"{"BackendState":"Running","Self":{"TailscaleIPs":["100.64.0.1"],"DNSName":"mac.test.","UserID":1},"Peer":{"node":{"ID":"exit1","HostName":"demo-exit","TailscaleIPs":["100.64.0.2"],"Online":true,"ExitNodeOption":true,"UserID":1}},"ExitNodeStatus":{"ID":"exit1","Online":true},"User":{"1":{"LoginName":"test@example.invalid","DisplayName":"Test owner"}}}"#.utf8)
    let model = DashboardModel()
    model.status = try! JSONDecoder().decode(TSStatus.self, from: fixture)
    check(model.rows.count == 2 && model.rows.first?.isSelf == true, "device list includes this Mac first")
    check(model.groups == ["Test owner"], "device groups use actual owner names")
    check(model.exitName == "demo-exit", "sidebar resolves selected exit node")
    model.chooseSection("Exit Nodes")
    check(model.filtered.count == 1, "exit-node section excludes regular devices")
    model.selected = "exit1"
    check(model.selectedDevice?.name == "demo-exit", "selection opens matching details")
    model.query = "100.64.0.2"
    check(model.filtered.count == 1, "search matches IP addresses")
    model.query = "absent"
    check(model.filtered.isEmpty && model.selectedDevice == nil, "filtered selection does not show a stale detail panel")
    model.status?.backendState = "Stopped"
    check(model.rows.allSatisfy { !$0.online }, "cached devices are not presented as live while stopped")
    let toggle = ConnectionToggle()
    check(toggle.intrinsicContentSize == NSSize(width: 54, height: 24), "shared switch geometry is 54 × 24 pt")
    check(toggle.frame.size == toggle.intrinsicContentSize, "switch frame and intrinsic size agree")
    toggle.state = .on
    check(toggle.state == .on, "switch exposes its actual checked state")
    let direct = ClientTransportStatus(checked: true)
    check(direct.modeLine.contains("без локального прокси"), "no proxy allows automatic direct mode")
    check(direct.indicator == .none, "no client or proxy leaves native status icon unchanged")
    let appOnly = ClientTransportStatus(runningClients: ["INCY"], checked: true)
    check(appOnly.clientLine.contains("запущен") && appOnly.proxyPort == nil, "running client is distinct from an available proxy")
    check(appOnly.indicator == .clientOnly, "running client gets amber status dot")
    let proxyOnly = ClientTransportStatus(proxyPort: 10808, checked: true)
    check(proxyOnly.modeLine.contains(":10808") && proxyOnly.runningClients.isEmpty, "background listener does not imply running GUI")
    check(proxyOnly.indicator == .proxyReady, "local listener gets green status dot")
    let nativeDot = TransportDotView.topLeftDotCenter(in: NSRect(x: 0, y: 0, width: 22, height: 22), nativeImage: true)
    check(nativeDot == NSPoint(x: 5, y: 17), "transport dot aligns with the native top-left matrix dot")
    let incyIfconfig = "en0: flags=8863<UP> mtu 1500\n\tinet 192.0.2.10 netmask 0xffffff00\nutun4: flags=8051<UP> mtu 1500\n\tinet 198.18.0.2 --> 198.18.0.1 netmask 0xffff0000\nutun5: flags=8051<UP> mtu 1280\n\tinet 100.64.0.1 --> 100.64.0.1\n"
    check(clientTunnelPresent(ifconfig: incyIfconfig), "INCY fake-IP utun is detected")
    check(!clientTunnelPresent(ifconfig: "en0: flags=8863<UP>\n\tinet 198.18.0.2 netmask 0xffffff00\nutun5: flags=8051<UP>\n\tinet 100.64.0.1 --> 100.64.0.1\n"), "fake-IP range off a utun is not INCY TUN")
    let vpnRoutes = """
    Routing tables

    Internet:
    Destination        Gateway            Flags               Netif Expire
    0/1                utun5              USc                 utun5
    default            link#22            UCSg                utun4
    default            192.0.2.1          UGScIg                en0
    128.0/1            utun5              USc                 utun5
    """
    check(splitDefaultRoutesPresent(netstat: vpnRoutes), "route helper /1 halves are detected")
    check(physicalDefaultRoutePresent(netstat: vpnRoutes), "scoped Wi-Fi default counts as a live uplink under a VPN")
    let asleepRoutes = "Destination        Gateway            Flags               Netif Expire\ndefault            link#22            UCSg                utun4\n"
    check(!physicalDefaultRoutePresent(netstat: asleepRoutes), "tunnel-only default is not a live uplink")
    check(!splitDefaultRoutesPresent(netstat: asleepRoutes), "no /1 halves after cleanup")
    model.status = try! JSONDecoder().decode(TSStatus.self, from: fixture)
    check(exitNodeTarget(of: model.status) == "100.64.0.2", "reconnect restores the exit node by its tailnet IP")
    print("Self-tests do not start the app UI, access the daemon, or modify VPN settings.")
}
