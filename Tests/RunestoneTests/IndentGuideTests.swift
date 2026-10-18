import XCTest
@testable import Runestone

/// Patch 0021: a hairline at each level of a line's indentation, and a ruler column.
@MainActor
final class IndentGuideTests: XCTestCase {
    private func makeTextView(_ text: String) -> (TextView, TextInputView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let textView = TextView(frame: window.bounds)
        window.addSubview(textView)
        textView.text = text
        textView.indentStrategy = .space(length: 2)
        let inputView = textView.subviews.first { $0 is TextInputView } as! TextInputView
        return (textView, inputView)
    }

    private func guides(_ input: TextInputView) -> [DecorationDrawItem] {
        input.subviews.compactMap { $0 as? DecorationView }.flatMap(\.items).filter {
            if case .indentGuide = $0.style { true } else { false }
        }
    }

    func testAGuidePerIndentLevel() {
        let (textView, input) = makeTextView("a\n  b\n    c\n")
        XCTAssertTrue(guides(input).isEmpty, "nothing is drawn until the toggle is on")
        textView.showIndentGuides = true
        textView.layoutIfNeeded()
        XCTAssertEqual(guides(input).count, 3, "one at level 1 for '  b', two for '    c'")
        XCTAssertEqual(guides(input).first?.rect.width, 1)
    }

    func testARulerColumnDrawsAGuideOnEveryLine() {
        let (textView, input) = makeTextView("a\nb\nc\n")
        textView.rulerColumn = 10
        textView.layoutIfNeeded()
        XCTAssertEqual(guides(input).count, 4, "one per visible line (the empty line after the last newline counts)")
    }
}
