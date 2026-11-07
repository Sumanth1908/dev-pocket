import SwiftUI

/// ⌘K: search tools, or open what's on the clipboard.
struct CommandPalette: View {
    @ObservedObject var coordinator: AppCoordinator

    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var isFieldFocused: Bool

    private struct Item: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        var shortcut: String?
        let run: () -> Void
    }

    private var items: [Item] {
        var items: [Item] = []
        if query.isEmpty,
           let suggestion = coordinator.clipboardSuggestion,
           let tool = UtilityRegistry.utility(id: suggestion.toolID) {
            items.append(Item(
                id: "clipboard",
                title: "Open clipboard in \(tool.name)",
                subtitle: "What you copied looks like \(suggestion.kind.displayName)",
                symbol: "doc.on.clipboard"
            ) { coordinator.openClipboardSuggestion() })
        }
        for (index, tool) in UtilityRegistry.all.enumerated() where tool.matches(query) {
            items.append(Item(
                id: tool.id,
                title: tool.name,
                subtitle: tool.summary,
                symbol: tool.symbol,
                shortcut: index < 9 ? "⌘\(index + 1)" : nil
            ) { coordinator.select(tool.id) })
        }
        return items
    }

    var body: some View {
        let items = items

        ZStack(alignment: .top) {
            Color.black.opacity(0.15)
                .contentShape(Rectangle())
                .onTapGesture { coordinator.isPaletteVisible = false }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search tools", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($isFieldFocused)
                        .onSubmit { run(items, at: highlighted) }
                        .onKeyPress(.downArrow) {
                            highlighted = min(highlighted + 1, max(items.count - 1, 0))
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            highlighted = max(highlighted - 1, 0)
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            coordinator.isPaletteVisible = false
                            return .handled
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()

                if items.isEmpty {
                    Text("No tools match “\(query)”")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(16)
                } else {
                    VStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            row(item, isHighlighted: index == highlighted)
                                .onTapGesture { run(items, at: index) }
                                .onHover { if $0 { highlighted = index } }
                        }
                    }
                    .padding(6)
                }
            }
            .frame(width: 440)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(.top, 64)
        }
        .onAppear {
            query = ""
            highlighted = 0
            isFieldFocused = true
        }
        .onChange(of: query) { highlighted = 0 }
    }

    private func row(_ item: Item, isHighlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHighlighted ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Color.primary.opacity(0.06)))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13, weight: .medium))
                Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let shortcut = item.shortcut {
                Text(shortcut).font(.caption).foregroundStyle(.tertiary)
            } else if isHighlighted {
                Image(systemName: "return").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? Color.primary.opacity(0.08) : .clear)
        )
        .contentShape(Rectangle())
    }

    private func run(_ items: [Item], at index: Int) {
        guard items.indices.contains(index) else { return }
        items[index].run()
    }
}
