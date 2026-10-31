import SwiftUI

/// One tool in the pocket. To add a new utility:
///   1. Put its pure logic in `Sources/DevPocketCore` (and test it).
///   2. Write a SwiftUI view for it in this folder.
///   3. Declare a `static let` on `DevUtility` next to the view.
///   4. Append it to `UtilityRegistry.all`.
struct DevUtility: Identifiable {
    let id: String
    let name: String
    /// SF Symbol name.
    let symbol: String
    let summary: String
    var keywords: [String] = []
    let makeView: () -> AnyView

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
    ]

    static func utility(id: DevUtility.ID?) -> DevUtility? {
        all.first { $0.id == id }
    }
}
