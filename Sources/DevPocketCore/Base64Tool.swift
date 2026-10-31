import Foundation

public enum Base64Error: LocalizedError, Equatable {
    case invalidInput
    case notUTF8(byteCount: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidInput: "Not valid Base64"
        case .notUTF8(let count): "Decoded \(count) bytes, but they aren't UTF-8 text"
        }
    }
}

public enum Base64Tool {
    public static func encode(_ text: String, urlSafe: Bool = false) -> String {
        let encoded = Data(text.utf8).base64EncodedString()
        guard urlSafe else { return encoded }
        return encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func decode(_ text: String) throws -> String {
        guard let data = data(from: text) else { throw Base64Error.invalidInput }
        guard let string = String(data: data, encoding: .utf8) else {
            throw Base64Error.notUTF8(byteCount: data.count)
        }
        return string
    }

    /// Lenient decoder: accepts standard or URL-safe alphabets, ignores
    /// whitespace, and tolerates missing padding.
    public static func data(from text: String) -> Data? {
        var normalized = String(text.filter { !$0.isWhitespace })
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 { normalized += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: normalized)
    }
}
