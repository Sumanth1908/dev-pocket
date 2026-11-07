import DevPocketCore
import SwiftUI

/// One tool in the pocket. To add a new utility:
///   1. Put its pure logic in `Sources/DevPocketCore` (and test it).
///   2. In this folder, write a `ToolModel` subclass for its state, a
///      content view, and (optionally) a controls view for the title bar.
///   3. Declare a `static let` on `DevUtility` next to them.
///   4. Append it to `UtilityRegistry.all`.
struct DevUtility: Identifiable {
    let id: String
    let name: String
    /// SF Symbol name.
    let symbol: String
    let summary: String
    let keywords: [String]
    /// Clipboard content this tool should open for automatically.
    let handles: Set<ContentKind>
    let makeModel: @MainActor () -> ToolModel
    let makeContent: @MainActor (ToolModel) -> AnyView
    /// Tool-specific controls shown in the window's title bar.
    let makeControls: @MainActor (ToolModel) -> AnyView

    init<Model: ToolModel, Content: View, Controls: View>(
        id: String,
        name: String,
        symbol: String,
        summary: String,
        keywords: [String] = [],
        handles: Set<ContentKind> = [],
        model: @escaping @MainActor () -> Model,
        @ViewBuilder content: @escaping @MainActor (Model) -> Content,
        @ViewBuilder controls: @escaping @MainActor (Model) -> Controls
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.summary = summary
        self.keywords = keywords
        self.handles = handles
        makeModel = model
        // The store always hands a tool the model it made, so the casts hold.
        makeContent = { AnyView(content($0 as! Model)) }
        makeControls = { AnyView(controls($0 as! Model)) }
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return ([name, summary] + keywords).contains { $0.lowercased().contains(q) }
    }
}

enum UtilityRegistry {
    static let all: [DevUtility] = [
        .jwtDecoder,
        .jsonFormatter,
        .base64,
        .epochConverter,
    ]

    static func utility(id: DevUtility.ID?) -> DevUtility? {
        all.first { $0.id == id }
    }

    static func utility(handling kind: ContentKind) -> DevUtility? {
        all.first { $0.handles.contains(kind) }
    }
}
