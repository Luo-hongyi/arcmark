import AppKit

/// Generates circular "first-letter" placeholder icons for links that have no favicon yet.
///
/// When a link's favicon is missing (still loading, fetch failed, or a non-http URL),
/// we render a colored disc with the domain's first letter — similar to Arc / Things / Notion.
/// The disc uses the workspace's accent color, so placeholders feel themed rather than
/// generic. Once the real favicon arrives, the caller replaces the placeholder as before.
///
/// This is a pure helper: it does no caching (list reloads are infrequent and cells are
/// recycled). If profiling shows hot spots, an `NSCache<NSString, NSImage>` keyed by
/// `"url|colorId|size"` can be added later without changing call sites.
enum PlaceholderIconGenerator {

    /// Extracts the display initial for a URL.
    ///
    /// Rules:
    /// 1. Parse the host from the URL.
    /// 2. Strip a leading `www.`.
    /// 3. Take the first character, uppercased.
    /// 4. Return `nil` if there is no host, or the first character is not a letter
    ///    (e.g. IP addresses, `localhost:3000` numeric segments) — callers fall back
    ///    to the existing `globe` SF Symbol in that case.
    ///
    /// - Parameter urlString: The raw URL string (e.g. `https://www.github.com/foo`).
    /// - Returns: A single uppercase letter, or `nil` if no clean initial can be derived.
    static func initial(for urlString: String) -> String? {
        // Tolerate schemeless input by prepending a scheme so URL(host:) works.
        let candidate: String
        let lower = urlString.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            candidate = urlString
        } else {
            candidate = "https://" + urlString
        }

        guard let url = URL(string: candidate),
              var host = url.host,
              !host.isEmpty else {
            return nil
        }

        if host.lowercased().hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        guard host.isNotEmpty else { return nil }

        guard let firstScalar = host.unicodeScalars.first else { return nil }
        let first = Character(firstScalar)
        guard first.isLetter else { return nil }

        return String(first).uppercased()
    }

    /// Renders a circular placeholder image.
    ///
    /// - Parameters:
    ///   - urlString: The link URL — used to derive the letter.
    ///   - accentColor: The workspace accent color id, used for the disc fill.
    ///   - size: The edge length (points) of the square image.
    /// - Returns: A rendered `NSImage`, or `nil` if no initial could be derived (caller
    ///   should fall back to the `globe` symbol).
    static func image(for urlString: String,
                      accentColor: WorkspaceColorId,
                      size: CGFloat) -> NSImage? {
        guard let letter = initial(for: urlString) else { return nil }

        // Disc color: the fully-saturated accent (`.color`), NOT the translucent
        // `.backgroundColor`. The background variant is meant for large surfaces blending
        // into the chrome (it's 0.92 alpha pastel in light / 18% accent in dark) — too pale
        // under a letter. Using the solid accent gives a consistent bright disc in both modes.
        let discColor = accentColor.color

        // Letter color: dark. All 8 workspace accents are light pastels (luma 0.55–0.86),
        // so a dark letter (contrast 12–18:1) is far more legible than white (contrast 1–2:1).
        // The disc is always a bright pastel regardless of appearance, so the letter stays
        // dark in both light and dark mode.
        let letterColor = NSColor(calibratedRed: 0.078, green: 0.078, blue: 0.078, alpha: 0.9)

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        NSBezierPath(ovalIn: rect).setClip()
        discColor.setFill()
        NSBezierPath(ovalIn: rect).fill()

        // Letter: bold, sized to ~60% of the disc, vertically centered.
        let font = NSFont.systemFont(ofSize: size * 0.6, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: letterColor
        ]
        let str = NSString(string: letter)
        let glyphSize = str.size(withAttributes: attributes)
        let drawOrigin = NSPoint(
            x: (size - glyphSize.width) / 2,
            y: (size - glyphSize.height) / 2 - (font.descender / 2)
        )
        str.draw(at: drawOrigin, withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
