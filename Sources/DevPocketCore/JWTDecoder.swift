import Foundation

public struct DecodedJWT {
    public enum Validity: Equatable {
        case valid(until: Date)
        case expired(at: Date)
        case notYetValid(from: Date)
        case noExpiry
    }

    /// Pretty-printed JSON.
    public let header: String
    /// Pretty-printed JSON.
    public let payload: String
    /// Raw Base64URL signature segment (not verified).
    public let signature: String
    public let algorithm: String?
    public let type: String?
    public let issuedAt: Date?
    public let notBefore: Date?
    public let expiresAt: Date?

    public func validity(at now: Date = Date()) -> Validity {
        if let notBefore, now < notBefore { return .notYetValid(from: notBefore) }
        guard let expiresAt else { return .noExpiry }
        return now < expiresAt ? .valid(until: expiresAt) : .expired(at: expiresAt)
    }
}

public enum JWTDecodeError: LocalizedError, Equatable {
    case empty
    case encrypted
    case wrongSegmentCount(Int)
    case invalidBase64(segment: String)
    case invalidJSON(segment: String)

    public var errorDescription: String? {
        switch self {
        case .empty: "Token is empty"
        case .encrypted: "This is an encrypted JWT (JWE) — it can't be decoded without the key"
        case .wrongSegmentCount(let n): "A JWT has 3 dot-separated parts, found \(n)"
        case .invalidBase64(let segment): "The \(segment) isn't valid Base64URL"
        case .invalidJSON(let segment): "The \(segment) isn't valid JSON"
        }
    }
}

public enum JWTDecoder {
    /// Decodes (does not verify) a JWT. Accepts an optional `Bearer ` prefix.
    public static func decode(_ raw: String) throws -> DecodedJWT {
        var token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") {
            token = String(token.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard !token.isEmpty else { throw JWTDecodeError.empty }

        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 5 { throw JWTDecodeError.encrypted }
        guard parts.count == 3 else { throw JWTDecodeError.wrongSegmentCount(parts.count) }

        let (headerJSON, header) = try decodeSegment(parts[0], name: "header")
        let (payloadJSON, payload) = try decodeSegment(parts[1], name: "payload")

        return DecodedJWT(
            header: (try? JSONTool.format(headerJSON)) ?? headerJSON,
            payload: (try? JSONTool.format(payloadJSON)) ?? payloadJSON,
            signature: parts[2],
            algorithm: header["alg"] as? String,
            type: header["typ"] as? String,
            issuedAt: date(payload["iat"]),
            notBefore: date(payload["nbf"]),
            expiresAt: date(payload["exp"])
        )
    }

    private static func decodeSegment(_ segment: String, name: String) throws -> (String, [String: Any]) {
        guard let data = Base64Tool.data(from: segment),
              let text = String(data: data, encoding: .utf8) else {
            throw JWTDecodeError.invalidBase64(segment: name)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JWTDecodeError.invalidJSON(segment: name)
        }
        return (text, object)
    }

    private static func date(_ value: Any?) -> Date? {
        (value as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
    }
}
