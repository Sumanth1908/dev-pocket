import AppKit
import SwiftUI

@main
struct DevPocketApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra("DevPocket", systemImage: "wrench.and.screwdriver") {
            MenuBarMenu(coordinator: coordinator)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Also covers `swift run`, where there's no Info.plist with LSUIElement.
        NSApp.setActivationPolicy(.accessory)
        AppCoordinator.shared.start()
    }
}
