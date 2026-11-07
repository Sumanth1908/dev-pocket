import DevPocketCore
import SwiftUI

extension DevUtility {
    static let jsonFormatter = DevUtility(
        id: "json",
        name: "JSON Formatter",
        symbol: "curlybraces",
        summary: "Validate, pretty-print or minify JSON",
        keywords: ["parse", "pretty", "minify", "validate", "beautify"],
        handles: [.json],
        model: { JSONModel() },
        content: { JSONFormatterView(model: $0) },
        controls: { JSONControls(model: $0) }
    )
}

final class JSONModel: ToolModel {
    enum Mode: String, CaseIterable, Identifiable {
        case pretty = "Pretty"
        case minify = "Minify"
        var id: Self { self }
    }

    enum Indent: String, CaseIterable, Identifiable {
        case two = "2 spaces"
        case four = "4 spaces"
        case tab = "Tab"
        var id: Self { self }

        var string: String {
            switch self {
            case .two: "  "
            case .four: "    "
            case .tab: "\t"
            }
        }
    }

    struct Formatted {
        let output: String
        /// How many layers of string escaping were removed first (0 = none).
        let unescapedLayers: Int
    }

    @Published var mode = Mode.pretty
    @Published var indent = Indent.two
    @Published var sortKeys = false

    /// Escaped JSON (`"{\"a\":1}"`, as found in logs) is unescaped first.
    var result: Result<Formatted, Error>? {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let indent = mode == .pretty ? indent.string : nil
        return Result {
            if let (json, layers) = JSONTool.unescapeJSON(input) {
                return Formatted(output: try JSONTool.format(json, indent: indent, sortKeys: sortKeys), unescapedLayers: layers)
            }
            return Formatted(output: try JSONTool.format(input, indent: indent, sortKeys: sortKeys), unescapedLayers: 0)
        }
    }

    override var status: ToolStatus {
        switch result {
        case .none:
            return .idle("Paste or type JSON. Escaped JSON from logs is unescaped automatically.")
        case .failure(let error):
            return ToolStatus(kind: .error, text: error.localizedDescription)
        case .success(let formatted):
            let sizes = "\(input.count) → \(formatted.output.count) chars"
            switch formatted.unescapedLayers {
            case 0: return ToolStatus(kind: .ok, text: "Valid JSON", detail: sizes)
            case 1: return ToolStatus(kind: .ok, text: "Valid JSON · unescaped from a string", detail: sizes)
            case let n: return ToolStatus(kind: .ok, text: "Valid JSON · unescaped \(n) times", detail: sizes)
            }
        }
    }

    override var primaryOutput: String? { try? result?.get().output }

    override var copyLabel: String { mode == .pretty ? "Copy Formatted" : "Copy Minified" }
}

struct JSONControls: View {
    @ObservedObject var model: JSONModel

    var body: some View {
        HStack(spacing: 10) {
            Picker("Mode", selection: $model.mode) {
                ForEach(JSONModel.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Picker("Indent", selection: $model.indent) {
                ForEach(JSONModel.Indent.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(model.mode == .minify)

            Toggle("Sort keys", isOn: $model.sortKeys)
        }
    }
}

struct JSONFormatterView: View {
    @ObservedObject var model: JSONModel

    var body: some View {
        let output = model.primaryOutput ?? ""
        let isUnescaped = ((try? model.result?.get())?.unescapedLayers ?? 0) > 0

        HSplitView {
            Pane("Input") {
                CodeEditor(text: $model.input, placeholder: "Paste or type JSON…")
            } accessory: {
                InputActions(text: $model.input)
            }
            .frame(minWidth: 220)
            .padding(.trailing, 6)

            Pane(isUnescaped ? "Output · unescaped" : "Output") {
                CodeEditor(text: .constant(output), isEditable: false)
            } accessory: {
                IconButton("arrow.uturn.left", help: "Use as input") { model.input = output }
                    .disabled(output.isEmpty)
                CopyMenu(text: output)
            }
            .frame(minWidth: 220)
            .padding(.leading, 6)
        }
        .padding(14)
    }
}
