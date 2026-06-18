import AppKit

/// Centralized design system constants for Arcmark.
///
/// `ThemeConstants` provides a single source of truth for all design values used throughout
/// the application. This ensures consistency and makes it easy to update the visual design
/// from a single location.
///
/// ## Structure
/// Constants are organized into nested structs by category:
/// - **Colors**: Brand colors and semantic color values
/// - **Opacity**: Standard opacity levels for layering and states
/// - **Fonts**: Typography with consistent sizing and weights
/// - **Spacing**: Standard spacing values for layout consistency
/// - **CornerRadius**: Rounding values for UI elements
/// - **Sizing**: Standard sizes for icons, buttons, and rows
/// - **Animation**: Timing values for smooth transitions
///
/// ## Usage
/// ```swift
/// // Colors
/// layer?.backgroundColor = ThemeConstants.Colors.darkGray.cgColor
///
/// // With opacity
/// let hoverColor = ThemeConstants.Colors.darkGray
///     .withAlphaComponent(ThemeConstants.Opacity.minimal)
///
/// // Typography
/// textField.font = ThemeConstants.Fonts.bodyRegular
///
/// // Spacing and sizing
/// stackView.spacing = ThemeConstants.Spacing.regular
/// imageView.frame.size = CGSize(
///     width: ThemeConstants.Sizing.iconMedium,
///     height: ThemeConstants.Sizing.iconMedium
/// )
///
/// // Animation
/// CATransaction.begin()
/// CATransaction.setAnimationDuration(ThemeConstants.Animation.durationFast)
/// CATransaction.setAnimationTimingFunction(ThemeConstants.Animation.timingFunction)
/// // ... animations
/// CATransaction.commit()
/// ```
///
/// ## Design Philosophy
/// - Use semantic names that describe purpose, not specific values
/// - Provide a progression of values (e.g., tiny → small → medium → large)
/// - Avoid magic numbers scattered throughout the codebase
/// - Make global design changes from a single file
struct ThemeConstants {

    // MARK: - Colors

    /// Standard color palette for the application.
    ///
    /// All colors here are *dynamic* (`NSColor(name:)`): they resolve to a light variant under
    /// the `aqua` appearance and a dark variant under `darkAqua`. Call sites are unchanged —
    /// AppKit re-resolves them automatically when the effective appearance changes, and the
    /// base classes (`BaseView` / `BaseControl`) plus the list reload path re-apply them.
    struct Colors {
        /// Primary foreground color used for text, icons, and UI elements.
        /// Light: Hex #141414 | RGB (20, 20, 20)
        /// Dark:  Hex #F5F5F5 | RGB (245, 245, 245)
        static let darkGray = Appearance.dynamicColor(
            light: NSColor(calibratedRed: 0.078, green: 0.078, blue: 0.078, alpha: 1.0),
            dark: NSColor(calibratedRed: 0.961, green: 0.961, blue: 0.961, alpha: 1.0)
        )

        /// Contrast color used for light text/icons on dark backgrounds.
        /// Resolves to dark gray (#141414) under the dark appearance so it stays a contrast color.
        static let white = Appearance.dynamicColor(
            light: NSColor.white,
            dark: NSColor(calibratedRed: 0.078, green: 0.078, blue: 0.078, alpha: 1.0)
        )

        /// App background used in settings and preferences views, and the current default
        /// workspace background.
        /// Light: Hex #E5E7EB | RGB (229, 231, 235)
        /// Dark:  Hex #1E1E1E | RGB (30, 30, 30)
        static let settingsBackground = Appearance.dynamicColor(
            light: NSColor(calibratedRed: 0.898, green: 0.906, blue: 0.922, alpha: 1.0),
            dark: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)
        )

        /// Deepest window background (used for dark-mode blending of workspace accent colors).
        /// Light: identical to `settingsBackground`.
        /// Dark:  Hex #161616 | RGB (22, 22, 22)
        static let windowBackground = Appearance.dynamicColor(
            light: NSColor(calibratedRed: 0.898, green: 0.906, blue: 0.922, alpha: 1.0),
            dark: NSColor(calibratedRed: 0.086, green: 0.086, blue: 0.086, alpha: 1.0)
        )
    }

    /// Appearance helpers for light/dark dynamic colors.
    enum Appearance {
        /// Returns `true` when the effective appearance is a dark variant.
        ///
        /// Since the app now uses **manual** appearance control (no "follow system"), the
        /// user's `AppearancePreference` is the authoritative source of truth.
        ///
        /// Resolution order:
        /// 1. The user's explicit `AppearancePreference` (AppDelegate forces window.appearance
        ///    to match it).
        /// 2. The passed-in appearance (only used when no preference is set yet, e.g. very
        ///    early launch or in unit tests that pass an explicit appearance).
        ///
        /// NOTE: We deliberately do NOT trust the `appearance` argument from `NSColor(name:)`
        /// providers when a preference exists. When `NSAppearance.current` is unset (common in
        /// non-draw call stacks like reload callbacks), AppKit passes a misleading appearance
        /// to the provider that resolves to darkAqua, which would break light mode.
        static func isDark(_ appearance: NSAppearance? = nil) -> Bool {
            // Preference is authoritative when set.
            let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.appearancePreference)
            if let raw, let pref = AppearancePreference(rawValue: raw) {
                return pref == .dark
            }
            // No preference yet (first launch before register(defaults:)) — fall back to the
            // explicit appearance, defaulting to light.
            if let appearance {
                return appearance.bestMatch(from: [
                    .darkAqua,
                    .vibrantDark,
                    .accessibilityHighContrastDarkAqua,
                    .accessibilityHighContrastVibrantDark
                ]) != nil
            }
            return false
        }

        /// Creates a dynamic `NSColor` that switches between `light` and `dark` based on the
        /// effective appearance at draw time. Re-resolves automatically on appearance change.
        static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
            NSColor(name: nil) { appearance in
                isDark(appearance) ? dark : light
            }
        }
    }

    // MARK: - Opacity

    /// Standard opacity levels for layering, hover states, and visual hierarchy.
    ///
    /// Use these constants with `NSColor.withAlphaComponent(_:)` to create
    /// semi-transparent colors with consistent opacity levels.
    ///
    /// Example:
    /// ```swift
    /// let hoverBackground = ThemeConstants.Colors.darkGray
    ///     .withAlphaComponent(ThemeConstants.Opacity.minimal)
    /// ```
    struct Opacity {
        /// Fully opaque (1.0) - No transparency
        static let full: CGFloat = 1.0

        /// High opacity (0.8) - Primary content with slight transparency
        static let high: CGFloat = 0.8

        /// Medium opacity (0.6) - Secondary content
        static let medium: CGFloat = 0.6

        /// Low opacity (0.4) - Tertiary content or disabled states
        static let low: CGFloat = 0.4

        /// Subtle opacity (0.15) - Selected or focused backgrounds
        static let subtle: CGFloat = 0.15

        /// Extra subtle opacity (0.10) - Very light backgrounds
        static let extraSubtle: CGFloat = 0.10

        /// Minimal opacity (0.06) - Hover states with barely visible tint
        static let minimal: CGFloat = 0.06
    }

    // MARK: - Typography

    /// Standard typography styles for text throughout the application.
    ///
    /// All fonts use the system font (San Francisco on macOS) at size 14 with varying weights.
    /// For custom sizes or weights, use the `systemFont(size:weight:)` helper function.
    ///
    /// Example:
    /// ```swift
    /// // Standard body text
    /// label.font = ThemeConstants.Fonts.bodyRegular
    ///
    /// // Custom size and weight
    /// titleLabel.font = ThemeConstants.Fonts.systemFont(size: 18, weight: .semibold)
    /// ```
    struct Fonts {
        /// Body text with regular weight (size 14, weight: regular)
        nonisolated(unsafe) static let bodyRegular = NSFont.systemFont(ofSize: 14, weight: .regular)

        /// Body text with semibold weight (size 14, weight: semibold) - Good for emphasis
        nonisolated(unsafe) static let bodySemibold = NSFont.systemFont(ofSize: 14, weight: .semibold)

        /// Body text with medium weight (size 14, weight: medium) - Subtle emphasis
        nonisolated(unsafe) static let bodyMedium = NSFont.systemFont(ofSize: 14, weight: .medium)

        /// Body text with bold weight (size 14, weight: bold) - Strong emphasis
        nonisolated(unsafe) static let bodyBold = NSFont.systemFont(ofSize: 14, weight: .bold)

        /// Creates a system font with custom size and weight.
        ///
        /// - Parameters:
        ///   - size: The point size of the font
        ///   - weight: The weight of the font (e.g., .regular, .semibold, .bold)
        /// - Returns: A system font with the specified size and weight
        static func systemFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
            NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

    // MARK: - Spacing

    /// Standard spacing values for consistent layout and padding.
    ///
    /// Use these values for margins, padding, gaps between elements, and insets.
    /// Following an 8-point grid system (with some exceptions) for visual consistency.
    ///
    /// Example:
    /// ```swift
    /// stackView.spacing = ThemeConstants.Spacing.regular
    /// view.layoutMargins = NSEdgeInsets(
    ///     top: ThemeConstants.Spacing.large,
    ///     left: ThemeConstants.Spacing.extraLarge,
    ///     bottom: ThemeConstants.Spacing.large,
    ///     right: ThemeConstants.Spacing.extraLarge
    /// )
    /// ```
    struct Spacing {
        /// Tiny spacing (4pt) - Minimal gaps within compact components
        static let tiny: CGFloat = 4

        /// Small spacing (6pt) - Tight spacing for related elements
        static let small: CGFloat = 6

        /// Medium spacing (8pt) - Standard spacing within components
        static let medium: CGFloat = 8

        /// Regular spacing (10pt) - Default spacing between elements
        static let regular: CGFloat = 10

        /// Large spacing (14pt) - Comfortable spacing between groups
        static let large: CGFloat = 14

        /// Extra large spacing (16pt) - Generous spacing for major sections
        static let extraLarge: CGFloat = 16

        /// Huge spacing (20pt) - Maximum spacing for clear separation
        static let huge: CGFloat = 20
    }

    // MARK: - Corner Radius

    /// Standard corner radius values for rounded UI elements.
    ///
    /// Use these values to maintain consistent rounding throughout the application.
    ///
    /// Example:
    /// ```swift
    /// layer?.cornerRadius = ThemeConstants.CornerRadius.medium
    ///
    /// // For perfect circles
    /// layer?.cornerRadius = ThemeConstants.CornerRadius.round(view.bounds.height)
    /// ```
    struct CornerRadius {
        /// Small radius (6pt) - Subtle rounding for small elements
        static let small: CGFloat = 6

        /// Medium radius (8pt) - Standard rounding for buttons and cards
        static let medium: CGFloat = 8

        /// Large radius (12pt) - Prominent rounding for larger elements
        static let large: CGFloat = 12

        /// Creates a perfectly round corner radius (half of the value).
        ///
        /// - Parameter value: The dimension (width or height) to make round
        /// - Returns: Half of the input value for perfect circular rounding
        static func round(_ value: CGFloat) -> CGFloat { value / 2 }
    }

    // MARK: - Sizing

    /// Standard sizing values for UI elements.
    ///
    /// Use these values to ensure consistent sizing of icons, buttons, and rows.
    ///
    /// Example:
    /// ```swift
    /// imageView.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)?
    ///     .withSymbolConfiguration(.init(pointSize: ThemeConstants.Sizing.iconMedium, weight: .regular))
    ///
    /// button.heightAnchor.constraint(equalToConstant: ThemeConstants.Sizing.buttonHeight).isActive = true
    /// ```
    struct Sizing {
        /// Small icon size (14pt) - Compact icons for inline use
        static let iconSmall: CGFloat = 14

        /// Medium icon size (18pt) - Standard icon size for most UI
        static let iconMedium: CGFloat = 18

        /// Large icon size (22pt) - Prominent icons for primary actions
        static let iconLarge: CGFloat = 22

        /// Extra large icon size (26pt) - Large icons for emphasis
        static let iconExtraLarge: CGFloat = 26

        /// Standard button height (32pt)
        static let buttonHeight: CGFloat = 32

        /// Standard row height (44pt) - For list and table rows
        static let rowHeight: CGFloat = 44

        static let pinnedTileHeight: CGFloat = 50

        /// Scroll shadow gradient height (32pt) - Used for vertical overscroll fade indicators
        static let scrollShadowHeight: CGFloat = 32

        /// Scroll shadow gradient width (32pt) - Used for horizontal overscroll fade indicators
        static let scrollShadowWidth: CGFloat = 32

        /// Number of columns in the pinned tabs grid
        static let pinnedTileColumns: Int = 4

        /// Maximum number of rows in the pinned tabs grid
        static let pinnedTileMaxRows: Int = 3
    }

    // MARK: - Animation

    /// Standard animation timing values for smooth transitions.
    ///
    /// Use these values with CATransaction or NSAnimationContext for consistent animations.
    ///
    /// Example:
    /// ```swift
    /// CATransaction.begin()
    /// CATransaction.setAnimationDuration(ThemeConstants.Animation.durationFast)
    /// CATransaction.setAnimationTimingFunction(ThemeConstants.Animation.timingFunction)
    /// layer?.opacity = 0.5
    /// CATransaction.commit()
    /// ```
    struct Animation {
        /// Fast animation duration (0.15s) - Quick feedback for hover states
        static let durationFast: TimeInterval = 0.15

        /// Normal animation duration (0.2s) - Standard transitions
        static let durationNormal: TimeInterval = 0.2

        /// Slow animation duration (0.3s) - Deliberate, noticeable animations
        static let durationSlow: TimeInterval = 0.3

        /// Standard easing function for smooth, natural motion.
        /// Uses ease-in-ease-out timing (slow start, fast middle, slow end).
        nonisolated(unsafe) static let timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    }
}
