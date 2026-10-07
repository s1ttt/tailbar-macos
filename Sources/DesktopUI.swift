import AppKit

private final class TopAlignedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

/// JSON objects can arrive split across arbitrary pipe reads, with pretty
/// printed whitespace and braces inside strings. No event content is logged.
struct JSONObjectStream {
    private var bytes = Data()
    private var depth = 0
    private var inString = false
    private var escaped = false

    mutating func feed(_ data: Data) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for byte in data {
            if depth == 0 && byte != 123 { continue }
            bytes.append(byte)
            if inString {
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { inString = false }
            } else {
                if byte == 34 { inString = true }
                else if byte == 123 { depth += 1 }
                else if byte == 125 { depth -= 1 }
            }
            if depth == 0 {
                if let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] { result.append(object) }
                bytes.removeAll(keepingCapacity: true)
            }
            if bytes.count > 8_000_000 { self = JSONObjectStream() }
        }
        return result
    }
}
