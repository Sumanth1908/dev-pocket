import AppKit
import SwiftUI

enum Theme {
    /// Matches the app icon's tile.
    static let brandGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.61, blue: 1.0), Color(red: 0.23, green: 0.39, blue: 0.91)],
        startPoint: .top,
        endPoint: .bottom
    )
}

func relativeDate(_ date: Date) -> String {
    let now = Date()
    if abs(date.timeIntervalSince(now)) < 1 { return "now" }
    return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: now)
}

/// Translucent window background.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// Lets the empty parts of a SwiftUI title bar drag the window.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.performZoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        }
    }
}
