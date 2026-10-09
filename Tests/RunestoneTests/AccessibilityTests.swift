import XCTest
@testable import Runestone

/// Patch 0014: VoiceOver surface.
@MainActor
final class AccessibilityTests: XCTestCase {
    private func make(_ text: String) -> (TextView, TextInputView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let textView = TextView(frame: window.bounds)
        window.addSubview(textView)
        textView.text = text
        return (textView, textView.subviews.first { $0 is TextInputView } as! TextInputView)
    }

    func testValueReadsLineColumnAndText() {
        let (textView, input) = make("let a = 1\nreturn a\n")
        textView.selectedRange = NSRange(location: 12, length: 0)
        XCTAssertTrue(input.isAccessibilityElement)
        XCTAssertEqual(input.accessibilityValue, "Line 2, column 3. return a")
    }

    func testLinesReadWithTheirLabeledDecorations() {
        let (textView, input) = make("let a = 1\n\nreturn b\n")
        textView.decorations = [
            Decoration(range: NSRange(location: 18, length: 1), style: .squiggle(.red), accessibilityLabel: "Error: b is undefined"),
            Decoration(range: NSRange(location: 0, length: 9), style: .gutterBar(.purple), accessibilityLabel: "Written by agent"),
        ]
        XCTAssertEqual(input.accessibilityContent(forLineNumber: 0), "let a = 1. Written by agent")
        XCTAssertEqual(input.accessibilityContent(forLineNumber: 1), "Blank")
        XCTAssertEqual(input.accessibilityContent(forLineNumber: 2), "return b. Error: b is undefined")
        XCTAssertNil(input.accessibilityContent(forLineNumber: 9))
    }

    func testDiagnosticsRotorMovesCaretAndWraps() throws {
        let (textView, input) = make("a\nb\nc\nd\n")
        textView.decorations = [
            Decoration(range: NSRange(location: 2, length: 1), style: .squiggle(.red), accessibilityLabel: "Error one"),
            Decoration(range: NSRange(location: 6, length: 1), style: .dottedUnderline(.yellow), accessibilityLabel: "Warning two"),
        ]
        textView.selectedRange = NSRange(location: 0, length: 0)
        let rotor = try XCTUnwrap(input.accessibilityCustomRotors?.first { $0.name == "Diagnostics" })
        let predicate = UIAccessibilityCustomRotorSearchPredicate()
        predicate.searchDirection = .next
        _ = rotor.itemSearchBlock(predicate)
        XCTAssertEqual(textView.selectedRange.location, 2)
        _ = rotor.itemSearchBlock(predicate)
        XCTAssertEqual(textView.selectedRange.location, 6)
        _ = rotor.itemSearchBlock(predicate)
        XCTAssertEqual(textView.selectedRange.location, 2, "wraps to the first")
    }
}
