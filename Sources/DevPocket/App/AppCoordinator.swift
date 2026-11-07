import AppKit
import Carbon.HIToolbox
import DevPocketCore
import ServiceManagement
import SwiftUI

/// Owns the app's windows and entry points (menu bar, floating bubble,
/// global hotkey), the tools' state, and the commands they share.
@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    static let hotKeyDisplay = "⌃⌥Space"

    private enum Keys {
        static let bubbleVisible = "bubbleVisible"
        static let panelPinned = "panelPinned"
        static let lastUtility = "lastUtility"
        static let detectsClipboard = "detectsClipboard"
        static let clearsOnHide = "clearsOnHide"
    }

    struct ClipboardSuggestion: Equatable {
        let kind: ContentKind
        let toolID: DevUtility.ID
        let text: String
    }

    @Published private(set) var selectedUtilityID: DevUtility.ID {
        didSet { UserDefaults.standard.set(selectedUtilityID, forKey: Keys.lastUtility) }
    }

    @Published var isPaletteVisible = false

    /// What the clipboard looked like the last time it was read.
    @Published private(set) var clipboardSuggestion: ClipboardSuggestion?

    /// Briefly set after ⌘⇧C / ⌥⌘C, for the status bar's confirmation.
    @Published private(set) var copyConfirmation: String?

    @Published var isBubbleVisible: Bool {
        didSet {
            UserDefaults.standard.set(isBubbleVisible, forKey: Keys.bubbleVisible)
            isBubbleVisible ? bubble?.show() : bubble?.hide()
        }
    }

    /// Keep the tool window above other apps' windows.
    @Published var isPanelPinned: Bool {
        didSet {
            UserDefaults.standard.set(isPanelPinned, forKey: Keys.panelPinned)
            panel.setPinned(isPanelPinned)
        }
    }

    /// Read the clipboard when the window opens and jump to the matching tool.
    @Published var detectsClipboard: Bool {
        didSet { UserDefaults.standard.set(detectsClipboard, forKey: Keys.detectsClipboard) }
    }

    /// Wipe every tool's input when the window hides (tokens are secrets).
    @Published var clearsOnHide: Bool {
        didSet { UserDefaults.standard.set(clearsOnHide, forKey: Keys.clearsOnHide) }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("DevPocket: couldn't update login item: \(error.localizedDescription)")
            }
        }
    }

    let store = ToolStore()

    var currentTool: DevUtility { UtilityRegistry.utility(id: selectedUtilityID) ?? UtilityRegistry.all[0] }
    var currentModel: ToolModel { store.model(for: currentTool) }

    private var bubble: BubbleController?
    private var hotKey: GlobalHotKey?
    private var copyResetTask: Task<Void, Never>?
    /// Pasteboard change count already looked at, so a clipboard is only
    /// routed once, and copies made inside DevPocket are ignored.
    private var seenClipboardChange = -1

    private lazy var panel: ToolPanelController = {
        let panel = ToolPanelController(coordinator: self)
        panel.onHide = { [weak self] in self?.panelDidHide() }
        panel.onResignKey = { [weak self] in self?.markClipboardSeen() }
        return panel
    }()

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.bubbleVisible: true,
            Keys.panelPinned: true,
            Keys.detectsClipboard: true,
            Keys.clearsOnHide: false,
        ])
        isBubbleVisible = defaults.bool(forKey: Keys.bubbleVisible)
        isPanelPinned = defaults.bool(forKey: Keys.panelPinned)
        detectsClipboard = defaults.bool(forKey: Keys.detectsClipboard)
        clearsOnHide = defaults.bool(forKey: Keys.clearsOnHide)
        let last = defaults.string(forKey: Keys.lastUtility)
        selectedUtilityID = UtilityRegistry.utility(id: last)?.id ?? UtilityRegistry.all[0].id
    }

    func start() {
        bubble = BubbleController(
            onClick: { [weak self] in self?.togglePanel() },
            menu: { [weak self] in self?.makeBubbleMenu() ?? NSMenu() }
        )
        if isBubbleVisible { bubble?.show() }

        hotKey = GlobalHotKey(keyCode: kVK_Space, modifiers: controlKey | optionKey) { [weak self] in
            self?.togglePanel()
        }
        if hotKey == nil { NSLog("DevPocket: \(Self.hotKeyDisplay) is taken by another app") }
    }

    // MARK: - Panel

    func togglePanel() {
        panel.isFrontmost ? hidePanel() : showPanel()
    }

    func showPanel() {
        ingestClipboard()
        panel.show()
    }

    /// Opens a specific tool; the clipboard is used only if it suits that tool.
    func open(_ id: DevUtility.ID) {
        select(id)
        ingestClipboard(preferring: id)
        panel.show()
    }

    func hidePanel() { panel.hide() }

    func select(_ id: DevUtility.ID) {
        selectedUtilityID = id
        isPaletteVisible = false
    }

    private func panelDidHide() {
        isPaletteVisible = false
        markClipboardSeen()
        if clearsOnHide { store.clearAll() }
    }

    // MARK: - Clipboard

    private func markClipboardSeen() {
        seenClipboardChange = NSPasteboard.general.changeCount
    }

    /// Reads the clipboard only if it changed since we last looked — and
    /// only in response to the user opening the window, never in the
    /// background.
    private func ingestClipboard(preferring toolID: DevUtility.ID? = nil) {
        guard detectsClipboard else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != seenClipboardChange else { return }
        seenClipboardChange = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string) else {
            clipboardSuggestion = nil
            return
        }
        ingest(text, preferring: toolID)
    }

    /// Detects what `text` is and fills the best tool with it. With
    /// `toolID`, only that tool is filled, and only if it can take `text`.
    func ingest(_ text: String, preferring toolID: DevUtility.ID? = nil) {
        let candidates = ContentDetector.detect(text).compactMap { detection in
            UtilityRegistry.utility(handling: detection.kind).map { (kind: detection.kind, tool: $0) }
        }
        guard let best = candidates.first else {
            clipboardSuggestion = nil
            return
        }
        clipboardSuggestion = ClipboardSuggestion(kind: best.kind, toolID: best.tool.id, text: text)

        let target = toolID == nil ? best : candidates.first { $0.tool.id == toolID }
        if let target { route(text, kind: target.kind, to: target.tool) }
    }

    func openClipboardSuggestion() {
        guard let suggestion = clipboardSuggestion,
              let tool = UtilityRegistry.utility(id: suggestion.toolID) else { return }
        route(suggestion.text, kind: suggestion.kind, to: tool)
        isPaletteVisible = false
    }

    /// Opens `toolID` with `text` as its input.
    func send(_ text: String, to toolID: DevUtility.ID) {
        guard let tool = UtilityRegistry.utility(id: toolID) else { return }
        select(tool.id)
        store.model(for: tool).input = text
    }

    private func route(_ text: String, kind: ContentKind, to tool: DevUtility) {
        selectedUtilityID = tool.id
        let model = store.model(for: tool)
        if model.input != text { model.accept(clipboard: text, kind: kind) }
    }

    // MARK: - Commands

    /// Window-level shortcuts. Returns true if handled.
    func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }

        switch (flags, key) {
        case ([.command], "k"):
            isPaletteVisible.toggle()
        case ([.command], "l"):
            currentModel.clear()
        case ([.command, .shift], "v"):
            if let text = Clipboard.paste() { currentModel.input = text }
        case ([.command, .shift], "c"):
            copyCurrentOutput()
        case ([.command, .option], "c"):
            copyCurrentOutput(escaped: true)
        case ([.command], _) where Int(key).map((1...9).contains) == true:
            let index = Int(key)! - 1
            guard UtilityRegistry.all.indices.contains(index) else { return false }
            select(UtilityRegistry.all[index].id)
        default:
            return false
        }
        return true
    }

    /// Esc closes the palette first, then the window.
    func handleEscape() {
        if isPaletteVisible {
            isPaletteVisible = false
        } else {
            hidePanel()
        }
    }

    /// Copies the current tool's main result, optionally as a JSON string.
    func copyCurrentOutput(escaped: Bool = false) {
        guard let output = currentModel.primaryOutput else { return }
        Clipboard.copy(escaped ? JSONTool.escape(output) : output)
        copyConfirmation = escaped ? "Copied as JSON string" : "Copied"
        copyResetTask?.cancel()
        copyResetTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            if !Task.isCancelled { copyConfirmation = nil }
        }
    }

    private func makeBubbleMenu() -> NSMenu {
        let menu = NSMenu()
        for tool in UtilityRegistry.all {
            menu.addItem(ClosureMenuItem(tool.name, symbol: tool.symbol) { [weak self] in self?.open(tool.id) })
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Hide Bubble") { [weak self] in self?.isBubbleVisible = false })
        menu.addItem(ClosureMenuItem("Quit DevPocket") { NSApp.terminate(nil) })
        return menu
    }
}
