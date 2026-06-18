import XCTest
@testable import ArcmarkCore

@MainActor
final class ThemeConstantsTests: XCTestCase {

    // MARK: - Color Tests

    func testColorsAreValid() {
        // Verify colors are non-nil dynamic color wrappers.
        XCTAssertNotNil(ThemeConstants.Colors.darkGray)
        XCTAssertNotNil(ThemeConstants.Colors.white)
        XCTAssertNotNil(ThemeConstants.Colors.settingsBackground)
        XCTAssertNotNil(ThemeConstants.Colors.windowBackground)
    }

    /// Helper: resolves a dynamic `NSColor` under a given appearance and reads its RGBA.
    ///
    /// Dynamic NSColors can't be queried for components directly; we set the current
    /// appearance and convert through the sRGB color space, then read RGBA.
    private func rgba(_ color: NSColor, appearance: NSAppearance = NSAppearance(named: .aqua)!) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        NSAppearance.current = appearance
        defer { NSAppearance.current = nil }
        let resolved = color.usingColorSpace(NSColorSpace.sRGB) ?? color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    func testDarkGrayColor() {
        // Light appearance: darkGray resolves to a dark value (near-black).
        let (r, g, b, a) = rgba(ThemeConstants.Colors.darkGray)
        XCTAssertLessThan(r, 0.15, "light darkGray should be dark (near-black)")
        XCTAssertEqual([r, g, b].max()!, [r, g, b].min()!, accuracy: 0.002, "darkGray is neutral (R=G=B)")
        XCTAssertEqual(a, 1.0, accuracy: 0.001)
    }

    func testDarkGrayColorDarkAppearance() {
        // Dark appearance: darkGray resolves to a light value (near-white), proving the
        // dynamic wrapper switches variants with the effective appearance.
        let (r, g, b, a) = rgba(ThemeConstants.Colors.darkGray, appearance: NSAppearance(named: .darkAqua)!)
        XCTAssertGreaterThan(r, 0.9, "dark darkGray should be light (near-white)")
        XCTAssertEqual([r, g, b].max()!, [r, g, b].min()!, accuracy: 0.002, "darkGray is neutral (R=G=B)")
        XCTAssertEqual(a, 1.0, accuracy: 0.001)
    }

    func testDarkGrayColorSwitchesWithAppearance() {
        // Core contract: the same constant resolves differently under light vs dark.
        let lightR = rgba(ThemeConstants.Colors.darkGray).0
        let darkR = rgba(ThemeConstants.Colors.darkGray, appearance: NSAppearance(named: .darkAqua)!).0
        XCTAssertGreaterThan(darkR - lightR, 0.7, "darkGray must differ dramatically between appearances")
    }

    func testSettingsBackgroundDarkAppearance() {
        let (r, _, _, _) = rgba(ThemeConstants.Colors.settingsBackground, appearance: NSAppearance(named: .darkAqua)!)
        // Dark settings background should be near-black, not the light gray (#E5E7EB ≈ 0.9).
        XCTAssertLessThan(r, 0.2)
    }

    // MARK: - Opacity Tests

    func testOpacityValuesInValidRange() {
        // All opacity values should be between 0 and 1
        XCTAssertGreaterThanOrEqual(ThemeConstants.Opacity.full, 0)
        XCTAssertLessThanOrEqual(ThemeConstants.Opacity.full, 1)

        XCTAssertGreaterThanOrEqual(ThemeConstants.Opacity.high, 0)
        XCTAssertLessThanOrEqual(ThemeConstants.Opacity.high, 1)

        XCTAssertGreaterThanOrEqual(ThemeConstants.Opacity.medium, 0)
        XCTAssertLessThanOrEqual(ThemeConstants.Opacity.medium, 1)

        XCTAssertGreaterThanOrEqual(ThemeConstants.Opacity.low, 0)
        XCTAssertLessThanOrEqual(ThemeConstants.Opacity.low, 1)

        XCTAssertGreaterThanOrEqual(ThemeConstants.Opacity.subtle, 0)
        XCTAssertLessThanOrEqual(ThemeConstants.Opacity.subtle, 1)

        XCTAssertGreaterThanOrEqual(ThemeConstants.Opacity.extraSubtle, 0)
        XCTAssertLessThanOrEqual(ThemeConstants.Opacity.extraSubtle, 1)

        XCTAssertGreaterThanOrEqual(ThemeConstants.Opacity.minimal, 0)
        XCTAssertLessThanOrEqual(ThemeConstants.Opacity.minimal, 1)
    }

    func testOpacityValuesOrdered() {
        // Verify opacity values are in descending order
        XCTAssertGreaterThan(ThemeConstants.Opacity.full, ThemeConstants.Opacity.high)
        XCTAssertGreaterThan(ThemeConstants.Opacity.high, ThemeConstants.Opacity.medium)
        XCTAssertGreaterThan(ThemeConstants.Opacity.medium, ThemeConstants.Opacity.low)
        XCTAssertGreaterThan(ThemeConstants.Opacity.low, ThemeConstants.Opacity.subtle)
        XCTAssertGreaterThan(ThemeConstants.Opacity.subtle, ThemeConstants.Opacity.extraSubtle)
        XCTAssertGreaterThan(ThemeConstants.Opacity.extraSubtle, ThemeConstants.Opacity.minimal)
    }

    // MARK: - Font Tests

    func testFontsAreSystemAvailable() {
        XCTAssertNotNil(ThemeConstants.Fonts.bodyRegular)
        XCTAssertNotNil(ThemeConstants.Fonts.bodySemibold)
        XCTAssertNotNil(ThemeConstants.Fonts.bodyMedium)
        XCTAssertNotNil(ThemeConstants.Fonts.bodyBold)

        XCTAssertEqual(ThemeConstants.Fonts.bodyRegular.pointSize, 14)
        XCTAssertEqual(ThemeConstants.Fonts.bodySemibold.pointSize, 14)
        XCTAssertEqual(ThemeConstants.Fonts.bodyMedium.pointSize, 14)
        XCTAssertEqual(ThemeConstants.Fonts.bodyBold.pointSize, 14)
    }

    func testSystemFontFunction() {
        let customFont = ThemeConstants.Fonts.systemFont(size: 16, weight: .light)
        XCTAssertNotNil(customFont)
        XCTAssertEqual(customFont.pointSize, 16)
    }

    // MARK: - Spacing Tests

    func testSpacingValuesArePositive() {
        XCTAssertGreaterThan(ThemeConstants.Spacing.tiny, 0)
        XCTAssertGreaterThan(ThemeConstants.Spacing.small, 0)
        XCTAssertGreaterThan(ThemeConstants.Spacing.medium, 0)
        XCTAssertGreaterThan(ThemeConstants.Spacing.regular, 0)
        XCTAssertGreaterThan(ThemeConstants.Spacing.large, 0)
        XCTAssertGreaterThan(ThemeConstants.Spacing.extraLarge, 0)
        XCTAssertGreaterThan(ThemeConstants.Spacing.huge, 0)
    }

    func testSpacingValuesOrdered() {
        // Verify spacing values are in ascending order
        XCTAssertLessThan(ThemeConstants.Spacing.tiny, ThemeConstants.Spacing.small)
        XCTAssertLessThan(ThemeConstants.Spacing.small, ThemeConstants.Spacing.medium)
        XCTAssertLessThan(ThemeConstants.Spacing.medium, ThemeConstants.Spacing.regular)
        XCTAssertLessThan(ThemeConstants.Spacing.regular, ThemeConstants.Spacing.large)
        XCTAssertLessThan(ThemeConstants.Spacing.large, ThemeConstants.Spacing.extraLarge)
        XCTAssertLessThan(ThemeConstants.Spacing.extraLarge, ThemeConstants.Spacing.huge)
    }

    // MARK: - Corner Radius Tests

    func testCornerRadiusValuesArePositive() {
        XCTAssertGreaterThan(ThemeConstants.CornerRadius.small, 0)
        XCTAssertGreaterThan(ThemeConstants.CornerRadius.medium, 0)
        XCTAssertGreaterThan(ThemeConstants.CornerRadius.large, 0)
    }

    func testCornerRadiusRoundFunction() {
        XCTAssertEqual(ThemeConstants.CornerRadius.round(100), 50)
        XCTAssertEqual(ThemeConstants.CornerRadius.round(50), 25)
        XCTAssertEqual(ThemeConstants.CornerRadius.round(20), 10)
    }

    // MARK: - Sizing Tests

    func testIconSizesArePositive() {
        XCTAssertGreaterThan(ThemeConstants.Sizing.iconSmall, 0)
        XCTAssertGreaterThan(ThemeConstants.Sizing.iconMedium, 0)
        XCTAssertGreaterThan(ThemeConstants.Sizing.iconLarge, 0)
        XCTAssertGreaterThan(ThemeConstants.Sizing.iconExtraLarge, 0)
    }

    func testIconSizesOrdered() {
        XCTAssertLessThan(ThemeConstants.Sizing.iconSmall, ThemeConstants.Sizing.iconMedium)
        XCTAssertLessThan(ThemeConstants.Sizing.iconMedium, ThemeConstants.Sizing.iconLarge)
        XCTAssertLessThan(ThemeConstants.Sizing.iconLarge, ThemeConstants.Sizing.iconExtraLarge)
    }

    func testButtonAndRowSizes() {
        XCTAssertGreaterThan(ThemeConstants.Sizing.buttonHeight, 0)
        XCTAssertGreaterThan(ThemeConstants.Sizing.rowHeight, 0)
    }

    // MARK: - Animation Tests

    func testAnimationDurationsArePositive() {
        XCTAssertGreaterThan(ThemeConstants.Animation.durationFast, 0)
        XCTAssertGreaterThan(ThemeConstants.Animation.durationNormal, 0)
        XCTAssertGreaterThan(ThemeConstants.Animation.durationSlow, 0)
    }

    func testAnimationDurationsOrdered() {
        XCTAssertLessThan(ThemeConstants.Animation.durationFast, ThemeConstants.Animation.durationNormal)
        XCTAssertLessThan(ThemeConstants.Animation.durationNormal, ThemeConstants.Animation.durationSlow)
    }

    func testAnimationTimingFunction() {
        XCTAssertNotNil(ThemeConstants.Animation.timingFunction)
    }
}
