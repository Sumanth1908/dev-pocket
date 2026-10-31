import DevPocketCore
import SwiftUI

extension DevUtility {
    static let jwtDecoder = DevUtility(
        id: "jwt",
        name: "JWT Decoder",
        symbol: "key.horizontal",
        summary: "Inspect a JSON Web Token's header, payload and expiry",
        keywords: ["token", "bearer", "auth", "oauth", "claims"]
    ) { AnyView(JWTDecoderView()) }
}

struct JWTDecoderView: View {
    @State private var token = ""

    var body: some View {
        let result: Result<DecodedJWT, Error>? = token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : Result { try JWTDecoder.decode(token) }

        VStack(alignment: .leading, spacing: 12) {
            Pane("Encoded token") {
                CodeEditor(text: $token, placeholder: "Paste a JWT (a leading \"Bearer \" is fine)…")
                    .frame(height: 96)
            } accessory: {
                Button("Paste") { token = Clipboard.paste() ?? token }
                Button("Clear") { token = "" }.disabled(token.isEmpty)
            }

            switch result {
            case .none:
                Text("Decoding happens locally — the token never leaves your Mac. The signature is not verified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            case .failure(let error):
                StatusBadge(.error, error.localizedDescription)
                Spacer()
            case .success(let jwt):
                ClaimsBar(jwt: jwt)
                HSplitView {
                    jsonPane("Header", jwt.header)
                        .frame(minWidth: 180)
                        .padding(.trailing, 6)
                    jsonPane("Payload", jwt.payload)
                        .frame(minWidth: 240)
                        .padding(.leading, 6)
                }
            }
        }
        .padding(16)
    }

    private func jsonPane(_ title: String, _ json: String) -> some View {
        Pane(title) {
            CodeEditor(text: .constant(json), isEditable: false)
        } accessory: {
            Button("Copy") { Clipboard.copy(json) }
        }
    }
}

private struct ClaimsBar: View {
    let jwt: DecodedJWT

    var body: some View {
        HStack(spacing: 8) {
            validity
            if let algorithm = jwt.algorithm { StatusBadge(.neutral, "alg: \(algorithm)") }
            if let issuedAt = jwt.issuedAt { claim("Issued", issuedAt) }
            if let expiresAt = jwt.expiresAt { claim("Expires", expiresAt) }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var validity: some View {
        switch jwt.validity() {
        case .valid(let until): StatusBadge(.ok, "Valid · expires \(relative(until))")
        case .expired(let at): StatusBadge(.error, "Expired \(relative(at))")
        case .notYetValid(let from): StatusBadge(.warning, "Not valid until \(relative(from))")
        case .noExpiry: StatusBadge(.neutral, "No expiry")
        }
    }

    private func claim(_ label: String, _ date: Date) -> some View {
        Text("\(label) \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .help(date.formatted(.iso8601))
    }

    private func relative(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
