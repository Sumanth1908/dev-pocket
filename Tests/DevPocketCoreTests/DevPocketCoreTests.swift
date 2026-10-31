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
