import AppKit

/// A single colored dot within the status item's 3×3 glyph. The glyph stays a
/// template image so it follows the menu bar's appearance; this transparent,
/// non-interactive view colors only the top-left dot.
final class TransportDotView: NSView {
    var indicator: TransportIndicator = .none {
        didSet { isHidden = indicator == .none; needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isHidden = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    static func topLeftDotCenter(in imageRect: NSRect) -> NSPoint {
        // TailbarGlyph's 18×18 canvas puts the top-left centre at 3.6 / 14.4.
        let fraction: CGFloat = 3.6 / 18.0
        return NSPoint(x: imageRect.minX + imageRect.width * fraction,
                       y: imageRect.maxY - imageRect.height * fraction)
    }

    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor
        switch indicator {
        case .none: return
        case .clientOnly: color = NSColor.systemOrange
        case .proxyReady: color = NSColor.systemGreen
        }

        let button = superview as? NSButton
        let imageRect = button?.cell?.imageRect(forBounds: button?.bounds ?? bounds)
            ?? NSRect(x: bounds.midX - 9, y: bounds.midY - 9, width: 18, height: 18)
        let center = Self.topLeftDotCenter(in: imageRect)
        let radius = imageRect.width * 1.8 / 18.0
        let dot = NSRect(x: center.x - radius, y: center.y - radius,
                         width: radius * 2, height: radius * 2)
        color.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }
}
