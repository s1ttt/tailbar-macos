import AppKit

enum TransportIndicator {
    case none
    case clientOnly
    case proxyReady
}

struct ClientTransportStatus {
    var runningClients: [String] = []
    var proxyPort: Int?
    var checked = false

    static func runningClientsNow() -> [String] {
        let apps = NSWorkspace.shared.runningApplications
        return [("INCY", "llc.itdev.incy"), ("Happ", "com.happ.www")].compactMap { name, id in
            apps.contains { $0.bundleIdentifier == id } ? name : nil
        }
    }
    var clientLine: String {
        guard checked else { return "Проверяем INCY / Happ…" }
        guard !runningClients.isEmpty else { return "INCY / Happ не запущены" }
        return runningClients.joined(separator: " + ") + (runningClients.count == 1 ? " запущен" : " запущены")
    }
    var modeLine: String {
        guard checked else { return "Автоматический выбор подключения" }
        return proxyPort.map { "Авто · локальный прокси :\($0)" } ?? "Авто · без локального прокси"
    }
    var indicator: TransportIndicator {
        guard checked else { return .none }
        if proxyPort != nil { return .proxyReady }
        return runningClients.isEmpty ? .none : .clientOnly
    }
    var menuSummary: String {
        guard checked else { return "INCY / Happ: checking…" }
        let clients = runningClients.joined(separator: " + ")
        if let port = proxyPort {
            return clients.isEmpty ? "Local proxy :\(port) available" : "\(clients) · proxy :\(port) available"
        }
        return clients.isEmpty ? "INCY / Happ not running · direct" : "\(clients) running · no local proxy"
    }
    var explanation: String {
        if let port = proxyPort {
            return "TCP-порт 127.0.0.1:\(port) доступен. Wrapper предпочитает этот локальный прокси. Проверка порта не подтверждает CONNECT, авторизацию или доступность интернета."
        }
        return "Локальный прокси не обнаружен. Подключение разрешено без него. Это не гарантирует обход других системных VPN/TUN. Если сеть блокирует Tailscale, запустите INCY или Happ."
    }
}
