import XCTest
@testable import ArcmarkCore

@MainActor
final class PlaceholderIconGeneratorTests: XCTestCase {

    // MARK: - Initial extraction

    func testInitialFromSimpleURL() {
        XCTAssertEqual(PlaceholderIconGenerator.initial(for: "https://github.com/owner/repo"), "G")
    }

    func testInitialStripsWWWPrefix() {
        XCTAssertEqual(PlaceholderIconGenerator.initial(for: "https://www.apple.com/mac"), "A")
    }

    func testInitialIsUppercased() {
        XCTAssertEqual(PlaceholderIconGenerator.initial(for: "https://fast.com"), "F")
    }

    func testInitialFromSchemelessURL() {
        // The generator tolerates missing scheme by prepending https:// internally.
        XCTAssertEqual(PlaceholderIconGenerator.initial(for: "example.com/path"), "E")
    }

    // MARK: - Fall-throughs returning nil

    func testInitialReturnsNilForIPAddress() {
        // First character '1' is not a letter → nil (caller falls back to globe).
        XCTAssertNil(PlaceholderIconGenerator.initial(for: "https://192.168.1.1"))
    }

    func testInitialReturnsNilForEmptyHost() {
        XCTAssertNil(PlaceholderIconGenerator.initial(for: "https:///path-only"))
    }

    func testInitialReturnsNilForMalformedInput() {
        XCTAssertNil(PlaceholderIconGenerator.initial(for: ""))
        XCTAssertNil(PlaceholderIconGenerator.initial(for: "   "))
    }

    // MARK: - Image rendering

    func testImageReturnsImageForValidURL() {
        let image = PlaceholderIconGenerator.image(for: "https://github.com",
                                                    accentColor: .ember,
                                                    size: 20)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size.width, 20)
        XCTAssertEqual(image?.size.height, 20)
        // Placeholder must not be a template (it carries its own color), unlike the globe symbol.
        XCTAssertEqual(image?.isTemplate, false)
    }

    func testImageReturnsNilForIPSoCallersCanFallBack() {
        XCTAssertNil(PlaceholderIconGenerator.image(for: "https://10.0.0.1",
                                                     accentColor: .ocean,
                                                     size: 16))
    }

    func testImageRenderedForEveryAccentColor() {
        // Smoke test: none of the accent colors should crash rendering.
        for colorId in WorkspaceColorId.allCases {
            let image = PlaceholderIconGenerator.image(for: "https://example.com",
                                                        accentColor: colorId,
                                                        size: 18)
            XCTAssertNotNil(image, "failed to render placeholder for \(colorId)")
        }
    }
}
