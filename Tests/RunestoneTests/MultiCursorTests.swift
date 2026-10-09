import XCTest
@testable import Runestone

/// Patch 0012: multi-cursor prototype.
@MainActor
final class MultiCursorTests: XCTestCase {
    private func makeTextView(_ text: String) -> (TextView, TextInputView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let textView = TextView(frame: window.bounds)
        window.addSubview(textView)
        textView.text = text
        let inputView = textView.subviews.first { $0 is TextInputView } as! TextInputView
        return (textView, inputView)
    }

    func testTypingAtThreeCaretsIncludingTwoOnOneLine() {
        let (textView, input) = makeTextView("ab\ncd\nef\n")
        textView.selectedRange = NSRange(location: 1, length: 0)     // a|b
        textView.additionalCaretLocations = [4, 5]                    // c|d and cd|
        input.insertText("X")
        XCTAssertEqual(textView.text, "aXb\ncXdX\nef\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertEqual(textView.additionalCaretLocations, [6, 8])
        input.insertText("Y")
        XCTAssertEqual(textView.text, "aXYb\ncXYdXY\nef\n")
    }

    func testBackspaceAtAllCaretsAndCaretAtStartDoesNothing() {
        let (textView, input) = makeTextView("abc\ndef\n")
        textView.selectedRange = NSRange(location: 2, length: 0)     // ab|c
        textView.additionalCaretLocations = [0, 6]                    // |abc and de|f
        input.deleteBackward()
        XCTAssertEqual(textView.text, "ac\ndf\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 1, length: 0))
        XCTAssertEqual(textView.additionalCaretLocations, [0, 4])
    }

    func testUndoRestoresTheOriginal() {
        let (textView, input) = makeTextView("one\ntwo\nthree\n")
        textView.selectedRange = NSRange(location: 0, length: 0)
        textView.additionalCaretLocations = [4, 8]
        input.insertText("// ")
        XCTAssertEqual(textView.text, "// one\n// two\n// three\n")
        textView.undoManager?.undo()
        XCTAssertEqual(textView.text, "one\ntwo\nthree\n")
    }

    func testCaretsThatMeetMerge() {
        let (textView, input) = makeTextView("ab\n")
        textView.selectedRange = NSRange(location: 2, length: 0)
        textView.additionalCaretLocations = [1]
        input.deleteBackward()            // deletes "a" and "b"
        XCTAssertEqual(textView.text, "\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 0, length: 0))
        XCTAssertEqual(textView.additionalCaretLocations, [], "the carets met and merged")
    }

    func testSecondaryCaretsAreDrawn() throws {
        let (textView, input) = makeTextView((0..<20).map { "line \($0)" }.joined(separator: "\n"))
        textView.selectedRange = NSRange(location: 0, length: 0)
        let starts = (1..<10).map { row in ((0..<row).map { "line \($0)\n" }.joined() as NSString).length }
        textView.additionalCaretLocations = starts
        textView.layoutIfNeeded()
        let carets = input.subviews.compactMap { $0 as? DecorationView }.flatMap(\.items)
            .filter { if case .caret = $0.style { true } else { false } }
        XCTAssertEqual(carets.count, 9)
        XCTAssertEqual(carets.first?.rect.width, 2)
    }
}
