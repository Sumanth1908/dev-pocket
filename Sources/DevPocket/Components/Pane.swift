import AppKit
import DevPocketCore
import SwiftUI

/// A titled editor card with optional trailing icon buttons. Utilities
/// compose their layouts out of these.
struct Pane<Content: View, Accessory: View>: View {
    let title: String
    /// Optional color dot before the title, to tie the pane to something.
    let tint: Color?
    let content: Content
    let accessory: Accessory

    init(_ title: String, tint: Color? = nil, @ViewBuilder content: () -> Content, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.tint = tint
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                if let tint {
                    Circle().fill(tint).frame(width: 7, height: 7).padding(.trailing, 4)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                accessory
            }
            .frame(height: 18)

            content
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        }
    }
}

extension Pane where Accessory == EmptyView {
    init(_ title: String, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, tint: tint, content: content, accessory: { EmptyView() })
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    init(_ symbol: String, help: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

/// Copy button for an output: click copies as-is; the arrow offers
/// escaped versions to paste into code, curl bodies or config.
struct CopyMenu: View {
    let text: String
    var what = "output"

    var body: some View {
        Menu {
            Button("Copy") { Clipboard.copy(text) }
            Button("Copy as JSON String") { Clipboard.copy(JSONTool.escape(text)) }
            Button("Copy as JSON String, No Quotes") { Clipboard.copy(JSONTool.escape(text, quoted: false)) }
            if let minified = try? JSONTool.minify(text), minified != text {
                Button("Copy Minified as JSON String") { Clipboard.copy(JSONTool.escape(minified)) }
            }
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
        } primaryAction: {
            Clipboard.copy(text)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .help("Copy \(what). The arrow has escaped versions.")
        .disabled(text.isEmpty)
    }
}

/// Paste / clear buttons for an input pane.
struct InputActions: View {
    @Binding var text: String

    var body: some View {
        IconButton("doc.on.clipboard", help: "Replace with clipboard (⌘⇧V)") {
            text = Clipboard.paste() ?? text
        }
        IconButton("xmark.circle", help: "Clear (⌘L)") { text = "" }
            .disabled(text.isEmpty)
    }
}

struct EmptyHint: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light))
            Text(text).font(.callout)
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum Clipboard {
    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    static func paste() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}

/// `NSMenuItem` that runs a closure, so AppKit menus can be built inline.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}
