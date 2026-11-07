import SwiftUI

/// Root of the tool window: header in the title bar, icon rail, the
/// current tool, and a status bar.
struct ToolHostView: View {
    @ObservedObject var coordinator: AppCoordinator
    let titlebarHeight: CGFloat

    var body: some View {
        let tool = coordinator.currentTool
        let model = coordinator.currentModel

        VStack(spacing: 0) {
            TopBar(coordinator: coordinator, tool: tool, model: model)
                .frame(height: titlebarHeight)
            Divider()
            HStack(spacing: 0) {
                ToolRail(coordinator: coordinator)
                Divider()
                tool.makeContent(model)
                    .id(tool.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.sendToTool, SendToToolAction { text, toolID in
                        coordinator.send(text, to: toolID)
                    })
            }
            Divider()
            StatusBar(coordinator: coordinator, model: model)
        }
        .background(VisualEffectBackground())
        .overlay {
            if coordinator.isPaletteVisible {
                CommandPalette(coordinator: coordinator)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: coordinator.isPaletteVisible)
        .ignoresSafeArea()
        .frame(minWidth: 660, minHeight: 400)
    }
}

private struct TopBar: View {
    /// Room for the traffic lights.
    private static let leadingInset: CGFloat = 80

    @ObservedObject var coordinator: AppCoordinator
    let tool: DevUtility
    @ObservedObject var model: ToolModel

    var body: some View {
        HStack(spacing: 10) {
            Text(tool.name)
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(1)

            if model.clipboardFill != nil {
                Label("From clipboard", systemImage: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .help("Filled in from what you copied. Edit it, or press ⌘L to clear.")
                    .transition(.opacity)
            }

            Spacer(minLength: 12)

            tool.makeControls(model)
                .controlSize(.small)

            Divider().frame(height: 16)

            IconButton("magnifyingglass", help: "Find a tool (⌘K)") {
                coordinator.isPaletteVisible = true
            }
            IconButton(coordinator.isPanelPinned ? "pin.fill" : "pin",
                       help: coordinator.isPanelPinned ? "Unpin from top" : "Keep window on top") {
                coordinator.isPanelPinned.toggle()
            }
        }
        .padding(.leading, Self.leadingInset)
        .padding(.trailing, 12)
        .frame(maxHeight: .infinity)
        .background(WindowDragArea())
        .animation(.easeOut(duration: 0.15), value: model.clipboardFill != nil)
    }
}

private struct ToolRail: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(UtilityRegistry.all.enumerated()), id: \.element.id) { index, tool in
                RailButton(
                    tool: tool,
                    shortcut: index < 9 ? "⌘\(index + 1)" : nil,
                    isSelected: tool.id == coordinator.selectedUtilityID
                ) {
                    coordinator.select(tool.id)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(width: 56)
        .background(Color.primary.opacity(0.03))
    }
}

private struct RailButton: View {
    let tool: DevUtility
    let shortcut: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 36, height: 36)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9).fill(Theme.brandGradient)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.08))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help([tool.name, shortcut].compactMap { $0 }.joined(separator: "  "))
        .accessibilityLabel(tool.name)
    }
}

private struct StatusBar: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var model: ToolModel

    var body: some View {
        let status = model.status

        HStack(spacing: 6) {
            Circle()
                .fill(color(for: status.kind))
                .frame(width: 7, height: 7)
            Text(status.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(status.text)
            if let detail = status.detail {
                Text("·").foregroundStyle(.tertiary)
                Text(detail).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: 12)

            if let confirmation = coordinator.copyConfirmation {
                Label(confirmation, systemImage: "checkmark")
                    .foregroundStyle(.green)
                    .transition(.opacity)
            } else {
                HStack(spacing: 14) {
                    shortcutButton("Copy as JSON String", "⌥⌘C") { coordinator.copyCurrentOutput(escaped: true) }
                    shortcutButton(model.copyLabel, "⌘⇧C") { coordinator.copyCurrentOutput() }
                }
                .disabled(model.primaryOutput == nil)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .animation(.easeOut(duration: 0.15), value: coordinator.copyConfirmation)
    }

    private func shortcutButton(_ title: String, _ shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text(shortcut).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.borderless)
    }

    private func color(for kind: ToolStatus.Kind) -> Color {
        switch kind {
        case .idle: .secondary.opacity(0.5)
        case .ok: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
