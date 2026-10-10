import UIKit

/// A visual annotation on a range of text: diagnostics, diff hunks, authorship (Omnie-dev patch 0011).
///
/// Decorations are drawn in their own views, above or below the text, so the text itself is never
/// re-typeset for them. Their ranges move with edits.
public struct Decoration: Hashable {
    public enum Style: Hashable {
        /// A wavy underline (errors).
        case squiggle(UIColor)
        /// A dotted underline (warnings).
        case dottedUnderline(UIColor)
        /// A background behind the text (diff hunks, word-level changes).
        case background(UIColor)
        /// A bar in the gutter next to every line the range touches (authorship, added/removed/modified).
        case gutterBar(UIColor)
        /// A dot in the gutter on the range's first line (info diagnostics).
        case gutterDot(UIColor)
        /// A caret bar (secondary carets in multi-cursor editing, patch 0012).
        case caret(UIColor)
        /// A fold marker in the gutter on the range's first line: › folded, ⌄ open (patch 0016).
        case gutterChevron(UIColor, folded: Bool)
    }

    public var id: String
    public var range: NSRange
    public var style: Style
    /// What VoiceOver says for this decoration ("Error: missing return", "Written by agent").
    /// Decorations with a label are reachable through the "Diagnostics" rotor and are read with
    /// their line. Patch 0014.
    public var accessibilityLabel: String?

    public init(id: String = UUID().uuidString, range: NSRange, style: Style, accessibilityLabel: String? = nil) {
        self.id = id
        self.range = range
        self.style = style
        self.accessibilityLabel = accessibilityLabel
    }

    var isGutter: Bool {
        switch style {
        case .gutterBar, .gutterDot, .gutterChevron: true
        default: false
        }
    }

    var isBackground: Bool {
        if case .background = style { return true }
        return false
    }

    /// Moves the range across an edit that replaced `editedRange` with `newLength` characters.
    func shifted(byReplacing editedRange: NSRange, newLength: Int) -> Decoration {
        let delta = newLength - editedRange.length
        var result = self
        if range.location >= editedRange.upperBound {
            // Entirely after the edit (insertion at the start counts as after: the text moves right).
            result.range.location += delta
        } else if range.upperBound <= editedRange.location {
            // Entirely before the edit.
        } else if range.location <= editedRange.location && range.upperBound >= editedRange.upperBound {
            // The edit is inside the decoration.
            result.range.length = max(0, range.length + delta)
        } else {
            // Partial overlap: cover what's left of the decoration plus the new text.
            let start = min(range.location, editedRange.location)
            let end = max(editedRange.location + newLength, range.upperBound + delta)
            result.range = NSRange(location: start, length: max(0, end - start))
        }
        return result
    }
}

/// One thing to draw, in the decoration view's own coordinates.
struct DecorationDrawItem: Equatable {
    var rect: CGRect
    var style: Decoration.Style
}

/// A viewport-sized, non-interactive view that draws decorations. Redraws only when its items change.
final class DecorationView: UIView {
    var items: [DecorationDrawItem] = [] {
        didSet {
            if items != oldValue { setNeedsDisplay() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        for item in items where item.rect.intersects(rect) {
            switch item.style {
            case .background(let color):
                color.setFill()
                UIBezierPath(rect: item.rect).fill()
            case .squiggle(let color):
                let path = UIBezierPath()
                let y = item.rect.maxY - 2
                let wavelength: CGFloat = 4, amplitude: CGFloat = 1.5
                var x = item.rect.minX
                path.move(to: CGPoint(x: x, y: y))
                var up = true
                while x < item.rect.maxX {
                    let next = min(x + wavelength / 2, item.rect.maxX)
                    path.addQuadCurve(to: CGPoint(x: next, y: y),
                                      controlPoint: CGPoint(x: (x + next) / 2, y: y + (up ? -amplitude : amplitude)))
                    up.toggle()
                    x = next
                }
                path.lineWidth = 1.5
                color.setStroke()
                path.stroke()
            case .dottedUnderline(let color):
                let path = UIBezierPath()
                let y = item.rect.maxY - 1.5
                path.move(to: CGPoint(x: item.rect.minX, y: y))
                path.addLine(to: CGPoint(x: item.rect.maxX, y: y))
                path.lineWidth = 1.5
                path.setLineDash([1.5, 2], count: 2, phase: 0)
                color.setStroke()
                path.stroke()
            case .gutterBar(let color):
                color.setFill()
                UIBezierPath(rect: item.rect).fill()
            case .gutterDot(let color):
                color.setFill()
                UIBezierPath(ovalIn: item.rect).fill()
            case .caret(let color):
                color.setFill()
                UIBezierPath(rect: item.rect).fill()
            case .gutterChevron(let color, let folded):
                let r = item.rect
                let path = UIBezierPath()
                if folded {
                    path.move(to: CGPoint(x: r.minX + r.width * 0.3, y: r.minY))
                    path.addLine(to: CGPoint(x: r.maxX - r.width * 0.2, y: r.midY))
                    path.addLine(to: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY))
                } else {
                    path.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.3))
                    path.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.2))
                    path.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.3))
                }
                path.lineWidth = 1.5
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                color.setStroke()
                path.stroke()
            }
        }
    }
}
