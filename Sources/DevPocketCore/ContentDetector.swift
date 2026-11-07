import Foundation

public enum ContentKind: String, CaseIterable, Sendable {
    case jwt, json, base64, timestamp

    public var displayName: String {
        switch self {
        case .jwt: "a JWT"
        case .json: "JSON"
        case .base64: "Base64"
        case .timestamp: "a timestamp"
        }
    }
}

public struct Detection: Equatable, Sendable {
    public let kind: ContentKind
    /// 0...1. Higher wins when several kinds match.
    public let confidence: Double
}

/// Guesses what a piece of text is so it can be routed to the right tool.
public enum ContentDetector {
    /// Large clipboards (logs, files) aren't worth guessing at.
    static let maxLength = 2_000_000

    /// All plausible kinds, most confident first.
    public static func detect(_ text: String) -> [Detection] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= maxLength else { return [] }

        var results: [Detection] = []
        if (try? JWTDecoder.decode(trimmed)) != nil {
            results.append(Detection(kind: .jwt, confidence: 0.95))
        }
        if let first = trimmed.first, first == "{" || first == "[" {
            // Broken JSON still belongs in the formatter, which shows the error.
            let isValid = (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil
            let confidence = isValid ? 0.9 : JSONTool.unescapeJSON(trimmed) != nil ? 0.85 : 0.4
            results.append(Detection(kind: .json, confidence: confidence))
        } else if trimmed.first == "\"", JSONTool.unescapeJSON(trimmed) != nil {
            results.append(Detection(kind: .json, confidence: 0.85))
        }
        if let confidence = base64Confidence(trimmed) {
            results.append(Detection(kind: .base64, confidence: confidence))
        }
        if let confidence = timestampConfidence(trimmed) {
            results.append(Detection(kind: .timestamp, confidence: confidence))
        }
        return results.sorted { $0.confidence > $1.confidence }
    }

    /// Plausible years for a bare number to be a timestamp: 2000–2100.
    private static let plausibleSeconds: ClosedRange<Double> = 946_684_800...4_102_444_800

    /// Epoch seconds or milliseconds in a plausible range, or a date string
    /// that starts like ISO 8601 (`2023-11-14T22:13` / `2023-11-14 22:13`).
    static func timestampConfidence(_ text: String) -> Double? {
        if text.wholeMatch(of: #/\d{10}|\d{13}/#) != nil, let value = Double(text) {
            let seconds = text.count == 13 ? value / 1000 : value
            return plausibleSeconds.contains(seconds) ? 0.7 : nil
        }
        if text.prefixMatch(of: #/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/#) != nil,
           EpochTool.parseDate(text, timeZone: .current) != nil {
            return 0.75
        }
        return nil
    }

    /// Base64 is only claimed when it decodes to readable UTF-8 text, which
    /// keeps ordinary words and hex strings from matching.
    static func base64Confidence(_ text: String) -> Double? {
        guard !text.contains(where: { $0 == " " || $0 == "\t" }) else { return nil }
        let compact = text.filter { !$0.isWhitespace }
        guard compact.count >= 8 else { return nil }

        let alphabet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=-_")
        guard compact.unicodeScalars.allSatisfy(alphabet.contains),
              let decoded = try? Base64Tool.decode(compact),
              !decoded.isEmpty else { return nil }

        let scalars = decoded.unicodeScalars
        let readable = scalars.filter { !CharacterSet.controlCharacters.contains($0) || "\n\r\t".unicodeScalars.contains($0) }
        guard Double(readable.count) / Double(scalars.count) >= 0.95 else { return nil }

        let decodesToJSON = (decoded.first == "{" || decoded.first == "[")
            && (try? JSONSerialization.jsonObject(with: Data(decoded.utf8))) != nil
        return decodesToJSON ? 0.85 : 0.6
    }
}
