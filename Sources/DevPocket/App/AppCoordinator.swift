import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

/// Owns the app's windows and entry points (menu bar, floating bubble,
/// global hotkey) and the state they share.
@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    static let hotKeyDisplay = "⌃⌥Space"

    private enum Keys {
        static let bubbleVisible = "bubbleVisible"
        static let panelPinned = "panelPinned"
        static let lastUtility = "lastUtility"
    }

    @Published var selectedUtilityID: DevUtility.ID? {
        didSet { UserDefaults.standard.set(selectedUtilityID, forKey: Keys.lastUtility) }
    }

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

    private var bubble: BubbleController?
    private lazy var panel = ToolPanelController(coordinator: self)
    private var hotKey: GlobalHotKey?

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.bubbleVisible: true, Keys.panelPinned: true])
        isBubbleVisible = defaults.bool(forKey: Keys.bubbleVisible)
        isPanelPinned = defaults.bool(forKey: Keys.panelPinned)
        let last = defaults.string(forKey: Keys.lastUtility)
        selectedUtilityID = UtilityRegistry.utility(id: last)?.id ?? UtilityRegistry.all.first?.id
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

    func togglePanel() { panel.toggle() }

    func showPanel() { panel.show() }

    func open(_ id: DevUtility.ID) {
        selectedUtilityID = id
        panel.show()
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
