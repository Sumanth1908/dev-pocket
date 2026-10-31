import DevPocketCore
import SwiftUI

extension DevUtility {
    static let base64 = DevUtility(
        id: "base64",
        name: "Base64",
        symbol: "arrow.left.arrow.right.square",
        summary: "Encode or decode Base64 / Base64URL text",
        keywords: ["encode", "decode", "base64url"]
    ) { AnyView(Base64View()) }
}

struct Base64View: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case encode = "Encode"
        case decode = "Decode"
        var id: Self { self }
    }

    @State private var input = ""
    @State private var mode = Mode.encode
    @State private var urlSafe = false

    var body: some View {
        let result: Result<String, Error>? = input.isEmpty
            ? nil
            : Result {
                switch mode {
                case .encode: Base64Tool.encode(input, urlSafe: urlSafe)
                case .decode: try Base64Tool.decode(input)
                }
            }
        let output = (try? result?.get()) ?? ""

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Toggle("URL-safe", isOn: $urlSafe)
                    .disabled(mode == .decode)
                    .help("Base64URL: - and _ instead of + and /, no padding. Decoding accepts both.")

                Spacer(minLength: 8)
                if case .failure(let error) = result {
                    StatusBadge(.error, error.localizedDescription)
                }
            }
            .controlSize(.small)

            Pane(mode == .encode ? "Text" : "Base64") {
                CodeEditor(text: $input, placeholder: mode == .encode ? "Text to encode…" : "Base64 to decode…")
            } accessory: {
                Button("Paste") { input = Clipboard.paste() ?? input }
                Button("Clear") { input = "" }.disabled(input.isEmpty)
            }

            Pane(mode == .encode ? "Base64" : "Text") {
                CodeEditor(text: .constant(output), isEditable: false)
            } accessory: {
                Button("Swap") {
                    input = output
                    mode = mode == .encode ? .decode : .encode
                }
                .disabled(output.isEmpty)
                Button("Copy") { Clipboard.copy(output) }.disabled(output.isEmpty)
            }
        }
        .padding(16)
    }
}
