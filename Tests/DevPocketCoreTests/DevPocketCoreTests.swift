import XCTest
@testable import DevPocketCore

final class JSONToolTests: XCTestCase {
    func testPrettyPrintPreservesKeyOrderAndCollapsesEmptyContainers() throws {
        let output = try JSONTool.format(#"{"b":1,"a":[1, 2],"e":{},"f":[ ]}"#)
        XCTAssertEqual(output, """
        {
          "b": 1,
          "a": [
            1,
            2
          ],
          "e": {},
          "f": []
        }
        """)
    }

    func testStringContentsAreUntouched() throws {
        let input = #"{"k": "a, {b}: [c] \"q\" \\"}"#
        XCTAssertEqual(try JSONTool.minify(input), #"{"k":"a, {b}: [c] \"q\" \\"}"#)
    }

    func testNumbersKeepTheirLiteralForm() throws {
        XCTAssertEqual(try JSONTool.minify(#"{ "x": 1.50, "y": 12345678901234567890 }"#),
                       #"{"x":1.50,"y":12345678901234567890}"#)
    }

    func testSortKeys() throws {
        XCTAssertEqual(try JSONTool.format(#"{"b":1,"a":2}"#, indent: nil, sortKeys: true), #"{"a":2,"b":1}"#)
    }

    func testTabIndent() throws {
        XCTAssertEqual(try JSONTool.format(#"{"a":1}"#, indent: "\t"), "{\n\t\"a\": 1\n}")
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try JSONTool.format(#"{"a": }"#))
    }
}

final class Base64ToolTests: XCTestCase {
    func testRoundTrip() throws {
        let text = "héllo wörld ✓"
        XCTAssertEqual(try Base64Tool.decode(Base64Tool.encode(text)), text)
        XCTAssertEqual(try Base64Tool.decode(Base64Tool.encode(text, urlSafe: true)), text)
    }

    func testURLSafeEncodingHasNoPaddingOrUnsafeChars() {
        let encoded = Base64Tool.encode("subjects?_d", urlSafe: true)
        XCTAssertFalse(encoded.contains("="))
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
    }

    func testInvalidInputThrows() {
        XCTAssertThrowsError(try Base64Tool.decode("abcde"))
    }
}

final class JWTDecoderTests: XCTestCase {
    // The well-known jwt.io sample token.
    let sample = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

    func testDecodesSampleToken() throws {
        let jwt = try JWTDecoder.decode(sample)
        XCTAssertEqual(jwt.algorithm, "HS256")
        XCTAssertEqual(jwt.type, "JWT")
        XCTAssertEqual(jwt.issuedAt, Date(timeIntervalSince1970: 1_516_239_022))
        XCTAssertTrue(jwt.payload.contains(#""name": "John Doe""#))
        XCTAssertEqual(jwt.validity(), .noExpiry)
    }

    func testAcceptsBearerPrefixAndWhitespace() throws {
        XCTAssertNoThrow(try JWTDecoder.decode("  Bearer \(sample)\n"))
    }

    func testValidity() throws {
        let payload = Base64Tool.encode(#"{"exp":2000,"nbf":1000}"#, urlSafe: true)
        let jwt = try JWTDecoder.decode("eyJhbGciOiJub25lIn0.\(payload).")
        XCTAssertEqual(jwt.validity(at: Date(timeIntervalSince1970: 500)), .notYetValid(from: Date(timeIntervalSince1970: 1000)))
        XCTAssertEqual(jwt.validity(at: Date(timeIntervalSince1970: 1500)), .valid(until: Date(timeIntervalSince1970: 2000)))
        XCTAssertEqual(jwt.validity(at: Date(timeIntervalSince1970: 2500)), .expired(at: Date(timeIntervalSince1970: 2000)))
    }

    func testErrors() {
        XCTAssertThrowsError(try JWTDecoder.decode("")) { XCTAssertEqual($0 as? JWTDecodeError, .empty) }
        XCTAssertThrowsError(try JWTDecoder.decode("a.b")) { XCTAssertEqual($0 as? JWTDecodeError, .wrongSegmentCount(2)) }
        XCTAssertThrowsError(try JWTDecoder.decode("a.b.c.d.e")) { XCTAssertEqual($0 as? JWTDecodeError, .encrypted) }
        XCTAssertThrowsError(try JWTDecoder.decode("e30.!!!.x")) { XCTAssertEqual($0 as? JWTDecodeError, .invalidBase64(segment: "payload")) }
    }
}

final class ContentDetectorTests: XCTestCase {
    let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

    func testJWT() {
        XCTAssertEqual(ContentDetector.detect(jwt).first?.kind, .jwt)
        XCTAssertEqual(ContentDetector.detect("Bearer \(jwt)\n").first?.kind, .jwt)
    }

    func testJSON() {
        XCTAssertEqual(ContentDetector.detect(#"  {"a": [1, 2]}"#), [Detection(kind: .json, confidence: 0.9)])
        XCTAssertEqual(ContentDetector.detect("[1, 2, 3]").first?.kind, .json)
    }

    func testBrokenJSONStillGoesToFormatterWithLowConfidence() {
        XCTAssertEqual(ContentDetector.detect(#"{"a": "#), [Detection(kind: .json, confidence: 0.4)])
    }

    func testBase64() {
        XCTAssertEqual(ContentDetector.detect(Base64Tool.encode("Hello, DevPocket!")), [Detection(kind: .base64, confidence: 0.6)])
        XCTAssertEqual(ContentDetector.detect(Base64Tool.encode(#"{"ok":true}"#, urlSafe: true)), [Detection(kind: .base64, confidence: 0.85)])
    }

    func testPlainTextMatchesNothing() {
        for text in ["", "   ", "hello world", "Optimization", "deadbeefcafe1234", "12345678", "true", "42", "https://example.com/a?b=c"] {
            XCTAssertEqual(ContentDetector.detect(text), [], "expected no detection for \(text.debugDescription)")
        }
    }
}

final class EpochToolTests: XCTestCase {
    let utc = TimeZone(identifier: "UTC")!
    let reference = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z

    func testUnitIsInferredFromMagnitude() throws {
        let cases: [(String, EpochUnit)] = [
            ("1700000000", .seconds),
            ("1700000000000", .milliseconds),
            ("1700000000000000", .microseconds),
            ("1700000000000000000", .nanoseconds),
        ]
        for (input, unit) in cases {
            let parsed = try EpochTool.parse(input)
            XCTAssertEqual(parsed.unit, unit, input)
            XCTAssertEqual(parsed.date.timeIntervalSince1970, 1_700_000_000, accuracy: 0.001, input)
        }
    }

    func testFractionalAndNegativeSeconds() throws {
        XCTAssertEqual(try EpochTool.parse("1700000000.5").date.timeIntervalSince1970, 1_700_000_000.5)
        XCTAssertEqual(try EpochTool.parse(" -1 ").date, Date(timeIntervalSince1970: -1))
    }

    func testDateStrings() throws {
        let cases: [(String, TimeInterval)] = [
            ("2023-11-14T22:13:20Z", 1_700_000_000),
            ("2023-11-14T22:13:20.123Z", 1_700_000_000.123),
            ("2023-11-15T03:43:20+05:30", 1_700_000_000),
            ("2023-11-14T22:13:20", 1_700_000_000),
            ("2023-11-14 22:13:20", 1_700_000_000),
            ("2023-11-14 22:13", 1_699_999_980),
            ("2023-11-14", 1_699_920_000),
            ("Tue, 14 Nov 2023 22:13:20 +0000", 1_700_000_000),
        ]
        for (input, expected) in cases {
            let parsed = try EpochTool.parse(input, timeZone: utc)
            XCTAssertNil(parsed.unit, input)
            XCTAssertEqual(parsed.date.timeIntervalSince1970, expected, accuracy: 0.0005, input)
        }
    }

    func testZonelessDatesUseTheGivenTimeZone() throws {
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        XCTAssertEqual(try EpochTool.parse("2023-11-15 03:43:20", timeZone: kolkata).date, reference)
    }

    func testNowAndErrors() throws {
        XCTAssertEqual(try EpochTool.parse("Now", now: reference), EpochParse(date: reference, unit: nil))
        XCTAssertThrowsError(try EpochTool.parse("hello"))
        XCTAssertThrowsError(try EpochTool.parse("12:30"))
    }

    func testFormatting() {
        XCTAssertEqual(EpochTool.epochString(reference, unit: .seconds), "1700000000")
        XCTAssertEqual(EpochTool.epochString(reference, unit: .milliseconds), "1700000000000")
        XCTAssertEqual(EpochTool.epochString(Date(timeIntervalSince1970: 1_700_000_000.5), unit: .seconds), "1700000000")
        XCTAssertEqual(EpochTool.epochString(Date(timeIntervalSince1970: 1_700_000_000.5), unit: .milliseconds), "1700000000500")
        XCTAssertEqual(EpochTool.iso8601(reference, timeZone: utc), "2023-11-14T22:13:20Z")
        XCTAssertEqual(EpochTool.iso8601(reference, timeZone: TimeZone(identifier: "Asia/Kolkata")!), "2023-11-15T03:43:20+05:30")
        XCTAssertEqual(EpochTool.iso8601(Date(timeIntervalSince1970: 1_700_000_000.25), timeZone: utc), "2023-11-14T22:13:20.250Z")
        XCTAssertEqual(EpochTool.rfc2822(reference, timeZone: utc), "Tue, 14 Nov 2023 22:13:20 +0000")
    }

    func testTimestampDetection() {
        XCTAssertEqual(ContentDetector.detect("1700000000"), [Detection(kind: .timestamp, confidence: 0.7)])
        XCTAssertEqual(ContentDetector.detect("1700000000000").first?.kind, .timestamp)
        XCTAssertEqual(ContentDetector.detect("2023-11-14T22:13:20Z").first?.kind, .timestamp)
        XCTAssertEqual(ContentDetector.detect("2023-11-14 22:13:20").first?.kind, .timestamp)
        // Out of the 2000–2100 range, or the wrong number of digits.
        for text in ["0000000001", "9999999999", "170000000", "17000000000", "2023-11-14"] {
            XCTAssertNil(ContentDetector.detect(text).first { $0.kind == .timestamp }, text)
        }
    }
}

final class JWTPartRangeTests: XCTestCase {
    private func parts(_ raw: String) -> [String] {
        JWTDecoder.partRanges(in: raw).map { "\($0.part.rawValue)=\(raw[$0.range])" }
    }

    func testFullToken() {
        XCTAssertEqual(parts("aaa.bbb.ccc"), ["header=aaa", "payload=bbb", "signature=ccc"])
    }

    func testIgnoresWhitespaceAndBearerPrefix() {
        XCTAssertEqual(parts("  Bearer   aaa.bbb.ccc \n"), ["header=aaa", "payload=bbb", "signature=ccc"])
    }

    func testPartialTokenWhileTyping() {
        XCTAssertEqual(parts("aaa"), ["header=aaa"])
        XCTAssertEqual(parts("aaa.bb"), ["header=aaa", "payload=bb"])
        XCTAssertEqual(parts("aaa.bbb."), ["header=aaa", "payload=bbb"])
    }

    func testPartsAreAssignedByPosition() {
        XCTAssertEqual(parts(".bbb.ccc"), ["payload=bbb", "signature=ccc"])
        XCTAssertEqual(parts("a.b.c.d.e"), ["header=a", "payload=b", "signature=c"])
    }

    func testEmpty() {
        XCTAssertEqual(parts(""), [])
        XCTAssertEqual(parts("   "), [])
        XCTAssertEqual(parts("Bearer "), [])
    }
}
