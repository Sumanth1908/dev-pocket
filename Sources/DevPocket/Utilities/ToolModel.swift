import DevPocketCore
import SwiftUI

struct ToolStatus: Equatable {
    enum Kind { case idle, ok, warning, error }

    var kind: Kind
    var text: String
    /// Secondary info shown after the status, e.g. sizes or algorithm.
    var detail: String?

    static func idle(_ text: String) -> ToolStatus { ToolStatus(kind: .idle, text: text) }
}

/// A tool's state. Lives in `ToolStore` rather than in views, so input
/// survives switching tools and hiding the window. Subclass per tool and
/// override the computed hooks the window chrome reads.
@MainActor
class ToolModel: ObservableObject {
    @Published var input = "" {
        didSet { if input != clipboardFill { clipboardFill = nil } }
    }

    /// Set while the input is exactly what was auto-filled from the clipboard.
    @Published private(set) var clipboardFill: String?

    /// Shown in the status bar.
    var status: ToolStatus { .idle("Waiting for input") }

    /// What ⌘⇧C and the status bar's copy button copy.
    var primaryOutput: String? { nil }

    var copyLabel: String { "Copy Output" }

    /// Fill from the clipboard. Override to adapt, e.g. switch to decode mode.
    func accept(clipboard text: String, kind: ContentKind) {
        clipboardFill = text
        input = text
    }

    func clear() { input = "" }
}

@MainActor
final class ToolStore {
    private var models: [DevUtility.ID: ToolModel] = [:]

    func model(for tool: DevUtility) -> ToolModel {
        if let model = models[tool.id] { return model }
        let model = tool.makeModel()
        models[tool.id] = model
        return model
    }

    func clearAll() {
        models.values.forEach { $0.clear() }
    }
}
