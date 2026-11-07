import DevPocketCore
import SwiftUI

extension DevUtility {
    static let jwtDecoder = DevUtility(
        id: "jwt",
        name: "JWT Decoder",
        symbol: "key.horizontal",
        summary: "Inspect a JSON Web Token's header, payload and expiry",
        keywords: ["token", "bearer", "auth", "oauth", "claims"],
        handles: [.jwt],
        model: { JWTModel() },
        content: { JWTDecoderView(model: $0) },
        controls: { _ in EmptyView() }
    )
}

final class JWTModel: ToolModel {
    var decoded: Result<DecodedJWT, Error>? {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Result { try JWTDecoder.decode(input) }
    }

    override var status: ToolStatus {
        switch decoded {
        case .none:
            return .idle("Paste a JWT. It's decoded on this Mac; the signature isn't verified.")
        case .failure(let error):
            return ToolStatus(kind: .error, text: error.localizedDescription)
        case .success(let jwt):
            let detail = [jwt.algorithm.map { "alg \($0)" }, "\(input.count) chars"].compactMap { $0 }.joined(separator: " · ")
            switch jwt.validity() {
            case .valid(let until):
                return ToolStatus(kind: .ok, text: "Valid · expires \(relativeDate(until))", detail: detail)
            case .expired(let at):
                return ToolStatus(kind: .warning, text: "Expired \(relativeDate(at))", detail: detail)
            case .notYetValid(let from):
                return ToolStatus(kind: .warning, text: "Not valid until \(relativeDate(from))", detail: detail)
            case .noExpiry:
                return ToolStatus(kind: .ok, text: "Decoded · no expiry", detail: detail)
            }
        }
    }

    override var primaryOutput: String? { try? decoded?.get().payload }

    override var copyLabel: String { "Copy Payload" }
}

/// The jwt.io convention, using system colors so they adapt to light/dark
/// mode and Increase Contrast.
extension JWTPart {
    var nsColor: NSColor {
        switch self {
        case .header: .systemPink
        case .payload: .systemPurple
        case .signature: .systemCyan
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    var label: String {
        switch self {
        case .header: "Header"
        case .payload: "Payload"
        case .signature: "Signature (not verified)"
        }
    }
}

struct JWTDecoderView: View {
    @ObservedObject var model: JWTModel

    private static let highlightParts: Highlighter = { text in
        JWTDecoder.partRanges(in: text).map { (NSRange($0.range, in: text), $0.part.nsColor) }
    }

    var body: some View {
        let jwt = try? model.decoded?.get()

        VStack(alignment: .leading, spacing: 12) {
            Pane("Token") {
                CodeEditor(
                    text: $model.input,
                    placeholder: "Paste a JWT (a leading \"Bearer \" is fine)…",
                    highlighter: Self.highlightParts
                )
                .frame(height: 84)
            } accessory: {
                InputActions(text: $model.input)
            }

            if !model.input.isEmpty {
                HStack(spacing: 16) {
                    PartLegend()
                    Spacer(minLength: 12)
                    if let jwt { ClaimTimes(jwt: jwt) }
                }
            }

            if let jwt {
                HSplitView {
                    jsonPane("Header", jwt.header, part: .header)
                        .frame(minWidth: 180)
                        .padding(.trailing, 6)
                    jsonPane("Payload", jwt.payload, part: .payload)
                        .frame(minWidth: 240)
                        .padding(.leading, 6)
                }
            } else {
                EmptyHint(symbol: "key.horizontal", text: "The header and payload will appear here")
            }
        }
        .padding(14)
    }

    private func jsonPane(_ title: String, _ json: String, part: JWTPart) -> some View {
        Pane(title, tint: part.color) {
            CodeEditor(text: .constant(json), isEditable: false)
        } accessory: {
            CopyMenu(text: json, what: title.lowercased())
        }
    }
}

/// Color key for the token's three parts.
private struct PartLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(JWTPart.allCases, id: \.self) { part in
                HStack(spacing: 5) {
                    Circle().fill(part.color).frame(width: 7, height: 7)
                    Text(part.label)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Issued / not-before / expiry; click one to open it in the Epoch Converter.
private struct ClaimTimes: View {
    let jwt: DecodedJWT

    @Environment(\.sendToTool) private var sendToTool

    var body: some View {
        let times = [("Issued", jwt.issuedAt), ("Not before", jwt.notBefore), ("Expires", jwt.expiresAt)]
            .compactMap { label, date in date.map { (label, $0) } }

        if !times.isEmpty {
            HStack(spacing: 16) {
                ForEach(times, id: \.0) { label, date in
                    HStack(spacing: 4) {
                        Text(label).foregroundStyle(.secondary)
                        Button(date.formatted(date: .abbreviated, time: .shortened)) {
                            sendToTool(EpochTool.epochString(date, unit: .seconds), to: DevUtility.epochConverter.id)
                        }
                        .buttonStyle(.link)
                    }
                    .help("\(date.formatted(.iso8601)). Click to open in the Epoch Converter.")
                }
            }
            .font(.caption)
        }
    }
}
