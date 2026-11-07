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

    @Published var mode = Mode.pretty
    @Published var indent = Indent.two
    @Published var sortKeys = false

    var result: Result<String, Error>? {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : Result { try JSONTool.format(input, indent: mode == .pretty ? indent.string : nil, sortKeys: sortKeys) }
    }

    override var status: ToolStatus {
        switch result {
        case .none: .idle("Paste or type JSON")
        case .failure(let error): ToolStatus(kind: .error, text: error.localizedDescription)
        case .success(let output): ToolStatus(kind: .ok, text: "Valid JSON", detail: "\(input.count) → \(output.count) chars")
        }
    }

    override var primaryOutput: String? { try? result?.get() }

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

        HSplitView {
            Pane("Input") {
                CodeEditor(text: $model.input, placeholder: "Paste or type JSON…")
            } accessory: {
                InputActions(text: $model.input)
            }
            .frame(minWidth: 220)
            .padding(.trailing, 6)

            Pane("Output") {
                CodeEditor(text: .constant(output), isEditable: false)
            } accessory: {
                IconButton("arrow.uturn.left", help: "Use as input") { model.input = output }
                    .disabled(output.isEmpty)
                IconButton("doc.on.doc", help: "Copy output") { Clipboard.copy(output) }
                    .disabled(output.isEmpty)
            }
            .frame(minWidth: 220)
            .padding(.leading, 6)
        }
        .padding(14)
    }
}
