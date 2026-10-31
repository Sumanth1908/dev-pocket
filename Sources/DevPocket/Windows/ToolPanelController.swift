import AppKit
import SwiftUI

/// The main tool window: a sidebar of utilities plus the selected one.
@MainActor
final class ToolPanelController {
    private static let autosaveName = "DevPocketToolPanel"

    private let panel: ToolPanel

    init(coordinator: AppCoordinator) {
        panel = ToolPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "DevPocket"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: ToolHostView(coordinator: coordinator))
        hosting.sizingOptions = [.minSize]
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: 860, height: 560))

        if !panel.setFrameUsingName(Self.autosaveName) { panel.center() }
        panel.setFrameAutosaveName(Self.autosaveName)
        setPinned(coordinator.isPanelPinned)
    }

    func setPinned(_ pinned: Bool) {
        panel.level = pinned ? .floating : .normal
    }

    func show() {
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if panel.isVisible && panel.isKeyWindow {
            panel.orderOut(nil)
        } else {
            show()
        }
    }
}

private final class ToolPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    /// A menu-bar-only app has no Edit menu to route these shortcuts, so
    /// handle the standard ones here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased()
        let action: Selector? = switch (flags, key) {
        case ([.command], "x"): #selector(NSText.cut(_:))
        case ([.command], "c"): #selector(NSText.copy(_:))
        case ([.command], "v"): #selector(NSText.paste(_:))
        case ([.command], "a"): #selector(NSText.selectAll(_:))
        case ([.command], "z"): Selector(("undo:"))
        case ([.command, .shift], "z"): Selector(("redo:"))
        default: nil
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) { return true }
        if flags == [.command], key == "w" {
            orderOut(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
