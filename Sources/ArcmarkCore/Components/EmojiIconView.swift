import AppKit

final class EmojiIconView: NSView {
    var emoji: String = "" {
        didSet {
            needsDisplay = true
        }
    }

    var pointSize: CGFloat = 16 {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !emoji.isEmpty else { return }

        let font = NSFont(name: "Apple Color Emoji", size: pointSize)
            ?? NSFont.systemFont(ofSize: pointSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let size = (emoji as NSString).size(withAttributes: attributes)
        let drawRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width + 8,
            height: size.height + 8
        )
        (emoji as NSString).draw(in: drawRect, withAttributes: attributes)
    }
}
