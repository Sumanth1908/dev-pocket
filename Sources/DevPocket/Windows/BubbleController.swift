import AppKit
import SwiftUI

/// The always-on-top floating bubble. Click toggles the tool window, drag
/// moves it (position is remembered), right-click shows a quick menu.
@MainActor
final class BubbleController {
    /// Visible circle.
    static let diameter: CGFloat = 44
    /// Window is larger than the circle so hover growth, shadow and the
    /// click ripple aren't clipped.
    private static let size: CGFloat = 72
    private static let margin = (size - diameter) / 2
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
        return NSPoint(x: visible.maxX - Self.size - 4, y: visible.midY)
    }

    /// Keeps the circle (not the transparent margin) fully on whichever
    /// screen it's mostly on.
    private func clamped(_ origin: NSPoint) -> NSPoint {
        let center = NSPoint(x: origin.x + Self.size / 2, y: origin.y + Self.size / 2)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }
        return NSPoint(
            x: min(max(origin.x, visible.minX - Self.margin), visible.maxX - Self.size + Self.margin),
            y: min(max(origin.y, visible.minY - Self.margin), visible.maxY - Self.size + Self.margin)
        )
    }
}

/// Interaction state the glyph animates from.
@MainActor
final class BubbleState: ObservableObject {
    @Published var isHovered = false
    @Published var isPressed = false
    @Published var isDragging = false
    /// Bumped on every click to trigger the ripple.
    @Published var clicks = 0
}

/// Handles mouse input itself (rather than letting SwiftUI do it) so a
/// click and a drag can be told apart reliably on a borderless panel.
private final class BubbleView: NSView {
    var onClick: () -> Void = {}
    var onDragEnded: () -> Void = {}
    var menuProvider: () -> NSMenu = { NSMenu() }

    let state = BubbleState()

    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero

    private var circleRect: NSRect {
        let d = BubbleController.diameter
        return NSRect(x: bounds.midX - d / 2, y: bounds.midY - d / 2, width: d, height: d)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        let glyph = NSHostingView(rootView: BubbleGlyph(state: state))
        glyph.sizingOptions = [] // don't let SwiftUI resize the bubble window
        glyph.frame = bounds
        glyph.autoresizingMask = [.width, .height]
        addSubview(glyph)
        toolTip = "DevPocket — click to open, drag to move, right-click for tools"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Only the circle is interactive; the transparent margin isn't.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return hypot(local.x - circleRect.midX, local.y - circleRect.midY) <= circleRect.width / 2 ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // .activeAlways: DevPocket is usually not the active app.
        addTrackingArea(NSTrackingArea(rect: circleRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { state.isHovered = true }

    override func mouseExited(with event: NSEvent) {
        // The window follows the cursor while dragging; ignore the noise.
        if !state.isDragging { state.isHovered = false }
    }

    override func mouseDown(with event: NSEvent) {
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        state.isPressed = true
        state.isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - dragStartMouse.x
        let dy = mouse.y - dragStartMouse.y
        if !state.isDragging, hypot(dx, dy) > 3 {
            state.isDragging = true
            state.isPressed = false
        }
        if state.isDragging {
            window?.setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if state.isDragging {
            onDragEnded()
        } else {
            state.clicks += 1
            onClick()
        }
        state.isPressed = false
        state.isDragging = false
        refreshHover()
    }

    override func rightMouseDown(with event: NSEvent) {
        state.isPressed = true
        NSMenu.popUpContextMenu(menuProvider(), with: event, for: self)
        // The menu swallowed the mouse-up and any exit events.
        state.isPressed = false
        refreshHover()
    }

    private func refreshHover() {
        guard let window else { return }
        let local = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        state.isHovered = circleRect.contains(local)
    }
}

private struct BubbleGlyph: View {
    @ObservedObject var state: BubbleState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLifted: Bool { (state.isHovered || state.isDragging) && !state.isPressed }

    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        if state.isPressed { return 0.88 }
        return isLifted ? 1.1 : 1
    }

    var body: some View {
        ZStack {
            if !reduceMotion { ripple }

            ZStack {
                Circle().fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                Circle().strokeBorder(.white.opacity(isLifted ? 0.5 : 0.3), lineWidth: 1)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isLifted && !reduceMotion ? -14 : 0))
            }
            .frame(width: BubbleController.diameter, height: BubbleController.diameter)
            .brightness(state.isPressed ? -0.08 : isLifted ? 0.06 : 0)
            .scaleEffect(scale)
            .shadow(color: .black.opacity(isLifted ? 0.38 : 0.3), radius: isLifted ? 7 : state.isPressed ? 2 : 4, y: isLifted ? 4 : 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: state.isHovered)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: state.isPressed)
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: state.isDragging)
    }

    /// Ring that expands and fades out on each click.
    private var ripple: some View {
        Circle()
            .strokeBorder(Color.accentColor, lineWidth: 2.5)
            .frame(width: BubbleController.diameter, height: BubbleController.diameter)
            .keyframeAnimator(initialValue: RippleFrame(), trigger: state.clicks) { content, frame in
                content.scaleEffect(frame.scale).opacity(frame.opacity)
            } keyframes: { _ in
                // MoveKeyframe jumps to the start value; a zero-duration
                // LinearKeyframe interpolates to NaN and crashes AppKit.
                KeyframeTrack(\.scale) {
                    MoveKeyframe(1)
                    CubicKeyframe(1.45, duration: 0.45)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0.9)
                    CubicKeyframe(0, duration: 0.45)
                }
            }
    }
}

private struct RippleFrame {
    var scale: CGFloat = 1
    var opacity: Double = 0
}
