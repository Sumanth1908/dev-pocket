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

struct JWTDecoderView: View {
    @ObservedObject var model: JWTModel

    var body: some View {
        let jwt = try? model.decoded?.get()

        VStack(alignment: .leading, spacing: 12) {
            Pane("Token") {
                CodeEditor(text: $model.input, placeholder: "Paste a JWT (a leading \"Bearer \" is fine)…")
                    .frame(height: 84)
            } accessory: {
                InputActions(text: $model.input)
            }

            if let jwt {
                ClaimTimes(jwt: jwt)
                HSplitView {
                    jsonPane("Header", jwt.header)
                        .frame(minWidth: 180)
                        .padding(.trailing, 6)
                    jsonPane("Payload", jwt.payload)
                        .frame(minWidth: 240)
                        .padding(.leading, 6)
                }
            } else {
                EmptyHint(symbol: "key.horizontal", text: "The header and payload will appear here")
            }
        }
        .padding(14)
    }

    private func jsonPane(_ title: String, _ json: String) -> some View {
        Pane(title) {
            CodeEditor(text: .constant(json), isEditable: false)
        } accessory: {
            IconButton("doc.on.doc", help: "Copy \(title.lowercased())") { Clipboard.copy(json) }
        }
    }
}

private struct ClaimTimes: View {
    let jwt: DecodedJWT

    var body: some View {
        let times = [("Issued", jwt.issuedAt), ("Not before", jwt.notBefore), ("Expires", jwt.expiresAt)]
            .compactMap { label, date in date.map { (label, $0) } }

        if !times.isEmpty {
            HStack(spacing: 16) {
                ForEach(times, id: \.0) { label, date in
                    HStack(spacing: 4) {
                        Text(label).foregroundStyle(.secondary)
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                    }
                    .help(date.formatted(.iso8601))
                }
            }
            .font(.caption)
        }
    }
}
