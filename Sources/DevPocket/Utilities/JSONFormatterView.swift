import DevPocketCore
import SwiftUI

extension DevUtility {
    static let jsonFormatter = DevUtility(
        id: "json",
        name: "JSON Formatter",
        symbol: "curlybraces",
        summary: "Validate, pretty-print or minify JSON",
        keywords: ["parse", "pretty", "minify", "validate", "beautify"]
    ) { AnyView(JSONFormatterView()) }
}

struct JSONFormatterView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case pretty = "Pretty"
        case minify = "Minify"
        var id: Self { self }
    }

    private enum Indent: String, CaseIterable, Identifiable {
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

    @State private var input = ""
    @State private var mode = Mode.pretty
    @State private var indent = Indent.two
    @State private var sortKeys = false

    var body: some View {
        let result: Result<String, Error>? = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : Result { try JSONTool.format(input, indent: mode == .pretty ? indent.string : nil, sortKeys: sortKeys) }
        let output = (try? result?.get()) ?? ""

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Picker("Indent", selection: $indent) {
                    ForEach(Indent.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(mode == .minify)

                Toggle("Sort keys", isOn: $sortKeys)

                Spacer(minLength: 8)
                status(result)
            }
            .controlSize(.small)

            HSplitView {
                Pane("Input") {
                    CodeEditor(text: $input, placeholder: "Paste or type JSON…")
                } accessory: {
                    Button("Paste") { input = Clipboard.paste() ?? input }
                    Button("Clear") { input = "" }.disabled(input.isEmpty)
                }
                .frame(minWidth: 220)
                .padding(.trailing, 6)

                Pane("Output") {
                    CodeEditor(text: .constant(output), isEditable: false)
                } accessory: {
                    Button("Use as Input") { input = output }.disabled(output.isEmpty)
                    Button("Copy") { Clipboard.copy(output) }.disabled(output.isEmpty)
                }
                .frame(minWidth: 220)
                .padding(.leading, 6)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func status(_ result: Result<String, Error>?) -> some View {
        switch result {
        case .none: StatusBadge(.neutral, "Waiting for input")
        case .success: StatusBadge(.ok, "Valid JSON")
        case .failure(let error): StatusBadge(.error, error.localizedDescription)
        }
    }
}
