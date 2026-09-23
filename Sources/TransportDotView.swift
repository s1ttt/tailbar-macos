import AppKit

/// A single colored dot within the status item's existing 3×3 matrix.
/// Keeping the native image as a template preserves its macOS appearance;
/// this transparent, non-interactive view colors only the top-left dot.
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

    static func topLeftDotCenter(in imageRect: NSRect, nativeImage: Bool) -> NSPoint {
        // Measured from the installed 22×22 macOS image: left/top dot centers
        // are x=5 and y=17 in AppKit's bottom-origin coordinates. The fallback
        // 18×18 matrix has its own documented 3.6/14.4 geometry.
        let fraction: CGFloat = nativeImage ? 5.0 / 22.0 : 3.6 / 18.0
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
            ?? NSRect(x: bounds.midX - 11, y: bounds.midY - 11, width: 22, height: 22)
        let nativeImage = (button?.image?.size.width ?? 22) >= 21
        let center = Self.topLeftDotCenter(in: imageRect, nativeImage: nativeImage)
        let radius = imageRect.width * (nativeImage ? 1.9 / 22.0 : 1.8 / 18.0)
        let dot = NSRect(x: center.x - radius, y: center.y - radius,
                         width: radius * 2, height: radius * 2)
        color.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }
}
