import AppKit
import SwiftUI

/// The always-on-top floating bubble. Click toggles the tool window, drag
/// moves it (position is remembered), right-click shows a quick menu.
@MainActor
final class BubbleController {
    private static let size: CGFloat = 56
    private static let originKey = "bubbleOrigin"

    private let panel: NSPanel

    init(onClick: @escaping () -> Void, menu: @escaping () -> NSMenu) {
        let frame = NSRect(x: 0, y: 0, width: Self.size, height: Self.size)
        panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // drawn by SwiftUI so it follows the circle
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let view = BubbleView(frame: frame)
        view.onClick = onClick
        view.menuProvider = menu
        view.onDragEnded = { [weak self] in self?.settle() }
        panel.contentView = view

        panel.setFrameOrigin(clamped(savedOrigin() ?? defaultOrigin()))
    }

    func show() { panel.orderFrontRegardless() }

    func hide() { panel.orderOut(nil) }

    private func settle() {
        let origin = clamped(panel.frame.origin)
        panel.setFrameOrigin(origin)
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: Self.originKey)
    }

    private func savedOrigin() -> NSPoint? {
        UserDefaults.standard.string(forKey: Self.originKey).map(NSPointFromString)
    }

    private func defaultOrigin() -> NSPoint {
        guard let visible = NSScreen.main?.visibleFrame else { return .zero }
        return NSPoint(x: visible.maxX - Self.size - 16, y: visible.midY)
    }

    /// Keeps the bubble fully on whichever screen it's mostly on.
    private func clamped(_ origin: NSPoint) -> NSPoint {
        let center = NSPoint(x: origin.x + Self.size / 2, y: origin.y + Self.size / 2)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }
        return NSPoint(
            x: min(max(origin.x, visible.minX), visible.maxX - Self.size),
            y: min(max(origin.y, visible.minY), visible.maxY - Self.size)
        )
    }
}

/// Handles mouse input itself (rather than letting SwiftUI do it) so a
/// click and a drag can be told apart reliably on a borderless panel.
private final class BubbleView: NSView {
    var onClick: () -> Void = {}
    var onDragEnded: () -> Void = {}
    var menuProvider: () -> NSMenu = { NSMenu() }

    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var isDragging = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        let glyph = NSHostingView(rootView: BubbleGlyph())
        glyph.sizingOptions = [] // don't let SwiftUI resize the bubble window
        glyph.frame = bounds
        glyph.autoresizingMask = [.width, .height]
        addSubview(glyph)
        toolTip = "DevPocket — click to open, drag to move, right-click for tools"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - dragStartMouse.x
        let dy = mouse.y - dragStartMouse.y
        if !isDragging, hypot(dx, dy) > 3 { isDragging = true }
        if isDragging {
            window?.setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        isDragging ? onDragEnded() : onClick()
        isDragging = false
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(menuProvider(), with: event, for: self)
    }
}

private struct BubbleGlyph: View {
    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .padding(6) // room for the shadow inside the window
    }
}
