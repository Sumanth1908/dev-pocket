import SwiftUI

struct MenuBarMenu: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Button("Open DevPocket") { coordinator.showPanel() }
            .keyboardShortcut(.space, modifiers: [.control, .option])

        Divider()

        ForEach(UtilityRegistry.all) { tool in
            Button {
                coordinator.open(tool.id)
            } label: {
                Label(tool.name, systemImage: tool.symbol)
            }
        }

        Divider()

        Toggle("Show Floating Bubble", isOn: $coordinator.isBubbleVisible)
        Toggle("Keep Window on Top", isOn: $coordinator.isPanelPinned)
        Toggle("Open With Clipboard Content", isOn: $coordinator.detectsClipboard)
        Toggle("Clear Inputs When Hidden", isOn: $coordinator.clearsOnHide)
        Toggle("Launch at Login", isOn: Binding(
            get: { coordinator.launchAtLogin },
            set: { coordinator.launchAtLogin = $0 }
        ))

        Divider()

        Button("Quit DevPocket") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
