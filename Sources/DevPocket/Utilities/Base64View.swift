import DevPocketCore
import SwiftUI

extension DevUtility {
    static let base64 = DevUtility(
        id: "base64",
        name: "Base64",
        symbol: "arrow.left.arrow.right.square",
        summary: "Encode or decode Base64 / Base64URL text",
        keywords: ["encode", "decode", "base64url"],
        handles: [.base64],
        model: { Base64Model() },
        content: { Base64View(model: $0) },
        controls: { Base64Controls(model: $0) }
    )
}

final class Base64Model: ToolModel {
    enum Mode: String, CaseIterable, Identifiable {
        case encode = "Encode"
        case decode = "Decode"
        var id: Self { self }
    }

    struct Output {
        let text: String
        /// Decoded text was JSON and has been pretty-printed.
        let isFormattedJSON: Bool
    }

    @Published var mode = Mode.encode
    @Published var urlSafe = false
    /// Pretty-print decoded output when it's a JSON object or array.
    @Published var formatsJSON = true

    var result: Result<Output, Error>? {
        guard !input.isEmpty else { return nil }
        return Result {
            switch mode {
            case .encode:
                return Output(text: Base64Tool.encode(input, urlSafe: urlSafe), isFormattedJSON: false)
            case .decode:
                let decoded = try Base64Tool.decode(input)
                let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                if formatsJSON, trimmed.first == "{" || trimmed.first == "[", let pretty = try? JSONTool.format(trimmed) {
                    return Output(text: pretty, isFormattedJSON: true)
                }
                return Output(text: decoded, isFormattedJSON: false)
            }
        }
    }

    override var status: ToolStatus {
        switch result {
        case .none:
            return .idle("Type text to encode, or paste Base64 to decode")
        case .failure(let error):
            return ToolStatus(kind: .error, text: error.localizedDescription)
        case .success(let output):
            let text = mode == .encode ? "Encoded" : output.isFormattedJSON ? "Decoded · JSON, formatted" : "Decoded"
            return ToolStatus(kind: .ok, text: text, detail: "\(input.count) → \(output.text.count) chars")
        }
    }

    override var primaryOutput: String? { try? result?.get().text }

    override var copyLabel: String { "Copy Result" }

    override func accept(clipboard text: String, kind: ContentKind) {
        if kind == .base64 { mode = .decode }
        super.accept(clipboard: text, kind: kind)
    }
}

struct Base64Controls: View {
    @ObservedObject var model: Base64Model

    var body: some View {
        HStack(spacing: 10) {
            Picker("Mode", selection: $model.mode) {
                ForEach(Base64Model.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            switch model.mode {
            case .encode:
                Toggle("URL-safe", isOn: $model.urlSafe)
                    .help("Base64URL: - and _ instead of + and /, no padding. Decoding accepts both.")
            case .decode:
                Toggle("Format JSON", isOn: $model.formatsJSON)
                    .help("Pretty-print the decoded text when it's JSON")
            }
        }
    }
}

struct Base64View: View {
    @ObservedObject var model: Base64Model

    var body: some View {
        let output = model.primaryOutput ?? ""

        VStack(spacing: 12) {
            Pane(model.mode == .encode ? "Text" : "Base64") {
                CodeEditor(text: $model.input, placeholder: model.mode == .encode ? "Text to encode…" : "Base64 to decode…")
            } accessory: {
                InputActions(text: $model.input)
            }

            Pane(model.mode == .encode ? "Base64" : "Text") {
                CodeEditor(text: .constant(output), isEditable: false)
            } accessory: {
                IconButton("arrow.up.arrow.down", help: "Swap input and output") {
                    model.input = output
                    model.mode = model.mode == .encode ? .decode : .encode
                }
                .disabled(output.isEmpty)
                CopyMenu(text: output)
            }
        }
        .padding(14)
    }
}
