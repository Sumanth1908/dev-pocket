import SwiftUI

struct ToolHostView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var query = ""

    private var tools: [DevUtility] {
        UtilityRegistry.all.filter { $0.matches(query) }
    }

    private var selected: DevUtility? {
        UtilityRegistry.utility(id: coordinator.selectedUtilityID)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 440)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            TextField("Search tools", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(10)
                .onSubmit {
                    if let first = tools.first { coordinator.selectedUtilityID = first.id }
                }

            List(tools, selection: $coordinator.selectedUtilityID) { tool in
                Label(tool.name, systemImage: tool.symbol)
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let tool = selected {
            VStack(spacing: 0) {
                header(for: tool)
                Divider()
                tool.makeView()
                    .id(tool.id)
            }
        } else {
            ContentUnavailableView("Pick a tool", systemImage: "wrench.and.screwdriver")
        }
    }

    private func header(for tool: DevUtility) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tool.symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name).font(.headline)
                Text(tool.summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                coordinator.isPanelPinned.toggle()
            } label: {
                Image(systemName: coordinator.isPanelPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(coordinator.isPanelPinned ? "Unpin from top" : "Keep window on top")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
