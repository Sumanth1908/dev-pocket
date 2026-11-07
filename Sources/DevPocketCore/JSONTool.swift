import Foundation

public struct JSONToolError: LocalizedError, Equatable {
    public let message: String
    public var errorDescription: String? { message }
}

public enum JSONTool {
    /// Validates `input` and re-indents it. Pass `indent: nil` to minify.
    ///
    /// Key order and number literals are preserved exactly as written, unless
    /// `sortKeys` is set (which round-trips through `JSONSerialization`).
    public static func format(_ input: String, indent: String? = "  ", sortKeys: Bool = false) throws -> String {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: Data(input.utf8), options: [.fragmentsAllowed])
        } catch {
            let ns = error as NSError
            let detail = ns.userInfo[NSDebugDescriptionErrorKey] as? String ?? ns.localizedDescription
            throw JSONToolError(message: detail)
        }

        var source = input
        if sortKeys {
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
            )
            source = String(decoding: data, as: UTF8.self)
        }
        return reindent(source, indent: indent)
    }

    public static func minify(_ input: String) throws -> String {
        try format(input, indent: nil)
    }

    /// `text` as a JSON string literal: `{"a":1}` → `"{\"a\":1}"`. Also what
    /// JavaScript, curl bodies and most config formats expect.
    public static func escape(_ text: String, quoted: Bool = true) -> String {
        var out = quoted ? "\"" : ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case _ where scalar.value < 0x20: out += String(format: "\\u%04x", scalar.value)
            default: out.unicodeScalars.append(scalar)
            }
        }
        return quoted ? out + "\"" : out
    }

    /// If `text` is JSON that has been escaped into a string — with or
    /// without the surrounding quotes, possibly several times over, as in
    /// logs — returns the JSON inside and how many layers were removed.
    /// Returns nil for plain JSON and for anything that isn't escaped JSON.
    public static func unescapeJSON(_ text: String) -> (json: String, layers: Int)? {
        var current = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for layers in 0...5 {
            if layers > 0, isContainer(current) { return (current, layers) }
            var inner = stringLiteralValue(current)
            if inner == nil, !current.hasPrefix("\"") {
                inner = stringLiteralValue("\"\(current)\"")
            }
            guard let next = inner?.trimmingCharacters(in: .whitespacesAndNewlines), next != current else { return nil }
            current = next
        }
        return nil
    }

    private static func stringLiteralValue(_ text: String) -> String? {
        guard text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") else { return nil }
        return (try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])) as? String
    }

    private static func isContainer(_ text: String) -> Bool {
        guard text.first == "{" || text.first == "[" else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil
    }

    /// Character-level re-indenter for already-valid JSON. Leaves string
    /// contents untouched and collapses empty containers to `{}` / `[]`.
    static func reindent(_ json: String, indent: String?) -> String {
        let chars = Array(json)
        var out = ""
        out.reserveCapacity(chars.count)
        var level = 0
        var inString = false
        var escaped = false

        func newline() {
            guard let indent else { return }
            out.append("\n")
            out.append(String(repeating: indent, count: level))
        }

        var i = 0
        while i < chars.count {
            let c = chars[i]
            defer { i += 1 }

            if inString {
                out.append(c)
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
                continue
            }

            switch c {
            case "\"":
                inString = true
                out.append(c)
            case "{", "[":
                var j = i + 1
                while j < chars.count, chars[j].isWhitespace { j += 1 }
                let closer: Character = c == "{" ? "}" : "]"
                if j < chars.count, chars[j] == closer {
                    out.append(c)
                    out.append(closer)
                    i = j
                } else {
                    out.append(c)
                    level += 1
                    newline()
                }
            case "}", "]":
                level -= 1
                newline()
                out.append(c)
            case ",":
                out.append(c)
                newline()
            case ":":
                out.append(c)
                if indent != nil { out.append(" ") }
            case _ where c.isWhitespace:
                break
            default:
                out.append(c)
            }
        }
        return out
    }
}
