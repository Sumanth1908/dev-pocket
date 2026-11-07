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

    @Published var mode = Mode.encode
    @Published var urlSafe = false

    var result: Result<String, Error>? {
        guard !input.isEmpty else { return nil }
        return Result {
            switch mode {
            case .encode: Base64Tool.encode(input, urlSafe: urlSafe)
            case .decode: try Base64Tool.decode(input)
            }
        }
    }

    override var status: ToolStatus {
        switch result {
        case .none: .idle("Type text to encode, or paste Base64 to decode")
        case .failure(let error): ToolStatus(kind: .error, text: error.localizedDescription)
        case .success(let output):
            ToolStatus(kind: .ok, text: mode == .encode ? "Encoded" : "Decoded", detail: "\(input.count) → \(output.count) chars")
        }
    }

    override var primaryOutput: String? { try? result?.get() }

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

            Toggle("URL-safe", isOn: $model.urlSafe)
                .disabled(model.mode == .decode)
                .help("Base64URL: - and _ instead of + and /, no padding. Decoding accepts both.")
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
                IconButton("doc.on.doc", help: "Copy output") { Clipboard.copy(output) }
                    .disabled(output.isEmpty)
            }
        }
        .padding(14)
    }
}
