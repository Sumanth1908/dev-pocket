import AppKit
import SwiftUI

/// The tool window: a translucent panel whose SwiftUI content runs up into
/// the title bar.
@MainActor
final class ToolPanelController: NSObject, NSWindowDelegate {
    private static let autosaveName = "DevPocketToolPanel.v2"

    private let panel: ToolPanel

    /// Called whenever the panel goes away (Esc, ⌘W, close button, toggle).
    var onHide: () -> Void = {}
    /// Called when the user switches to another app or window.
    var onResignKey: () -> Void = {}

    var isVisible: Bool { panel.isVisible }
    var isFrontmost: Bool { panel.isVisible && panel.isKeyWindow }

    init(coordinator: AppCoordinator) {
        panel = ToolPanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.title = "DevPocket"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        // An empty toolbar gives a taller, unified title bar with the
        // traffic lights centred in it — room for our own header.
        panel.toolbar = NSToolbar(identifier: "DevPocketToolbar")
        panel.toolbarStyle = .unifiedCompact
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        panel.onKeyEquivalent = { [weak coordinator] in coordinator?.handleKeyEquivalent($0) ?? false }
        panel.onCancel = { [weak coordinator] in coordinator?.handleEscape() }

        let titlebarHeight = panel.frame.height - panel.contentLayoutRect.height
        let hosting = NSHostingView(rootView: ToolHostView(coordinator: coordinator, titlebarHeight: titlebarHeight))
        hosting.sizingOptions = [.minSize]
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: 820, height: 520))

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

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        onHide()
    }

    func windowWillClose(_ notification: Notification) { onHide() }

    func windowDidResignKey(_ notification: Notification) { onResignKey() }
}

private final class ToolPanel: NSPanel {
    var onKeyEquivalent: ((NSEvent) -> Bool)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyEquivalent?(event) == true { return true }

        // A menu-bar-only app has no Edit menu to route these shortcuts, so
        // handle the standard ones here.
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
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
