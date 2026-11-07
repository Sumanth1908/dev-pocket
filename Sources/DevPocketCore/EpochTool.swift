import Foundation

public enum EpochUnit: String, CaseIterable, Sendable {
    case seconds, milliseconds, microseconds, nanoseconds

    var perSecond: Double {
        switch self {
        case .seconds: 1
        case .milliseconds: 1_000
        case .microseconds: 1_000_000
        case .nanoseconds: 1_000_000_000
        }
    }
}

public struct EpochParse: Equatable, Sendable {
    public let date: Date
    /// The unit a numeric input was read as; nil when the input was a date.
    public let unit: EpochUnit?
}

public struct EpochError: LocalizedError, Equatable {
    public var errorDescription: String? {
        "Not an epoch or a date I recognize. Try 1700000000, 2023-11-14T22:13:20Z or “now”."
    }
}

public enum EpochTool {
    /// Reads a Unix timestamp (unit inferred from its size), a date string,
    /// or "now". `timeZone` applies to date strings that don't carry one.
    public static func parse(_ raw: String, timeZone: TimeZone = .current, now: Date = Date()) throws -> EpochParse {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.lowercased() == "now" { return EpochParse(date: now, unit: nil) }

        if input.wholeMatch(of: #/-?\d+(\.\d+)?/#) != nil, let value = Double(input) {
            let unit = unit(for: value)
            return EpochParse(date: Date(timeIntervalSince1970: value / unit.perSecond), unit: unit)
        }

        if let date = parseDate(input, timeZone: timeZone) {
            return EpochParse(date: date, unit: nil)
        }
        throw EpochError()
    }

    /// Infers the unit from magnitude: anything up to 10^11 is seconds
    /// (which reaches the year 5138), each further 1000× is the next unit.
    public static func unit(for value: Double) -> EpochUnit {
        switch abs(value) {
        case ..<1e11: .seconds
        case ..<1e14: .milliseconds
        case ..<1e17: .microseconds
        default: .nanoseconds
        }
    }

    /// Whole seconds or milliseconds since 1970 (seconds round down).
    public static func epochString(_ date: Date, unit: EpochUnit) -> String {
        let seconds = date.timeIntervalSince1970
        if unit == .seconds { return String(Int64(seconds.rounded(.down))) }
        return String(Int64((seconds * unit.perSecond).rounded()))
    }

    /// ISO 8601 in `timeZone`, e.g. `2023-11-14T22:13:20Z` or `…+05:30`.
    /// Includes milliseconds only when the date has them.
    public static func iso8601(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        if date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) != 0 {
            formatter.formatOptions.insert(.withFractionalSeconds)
        }
        return formatter.string(from: date)
    }

    /// RFC 2822, as used in email and HTTP headers.
    public static func rfc2822(_ date: Date, timeZone: TimeZone) -> String {
        posixFormatter("EEE, dd MMM yyyy HH:mm:ss Z", timeZone: timeZone).string(from: date)
    }

    // MARK: - Date strings

    /// Formats tried after ISO 8601 with an offset, most specific first.
    private static let fallbackFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "dd MMM yyyy HH:mm:ss Z",
    ]

    static func parseDate(_ input: String, timeZone: TimeZone) -> Date? {
        let iso = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [[.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]] {
            iso.formatOptions = options
            if let date = iso.date(from: input) { return date }
        }
        for format in fallbackFormats {
            if let date = posixFormatter(format, timeZone: timeZone).date(from: input) { return date }
        }
        return nil
    }

    private static func posixFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
