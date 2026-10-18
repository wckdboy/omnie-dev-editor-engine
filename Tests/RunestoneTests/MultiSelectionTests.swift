import XCTest
@testable import Runestone

/// Patch 0019: multi-selection. Every selection may have a length; typing and backspace apply at all
/// of them in one undo group, and the selections move with the edits.
@MainActor
final class MultiSelectionTests: XCTestCase {
    private func makeTextView(_ text: String) -> (TextView, TextInputView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let textView = TextView(frame: window.bounds)
        window.addSubview(textView)
        textView.text = text
        let inputView = textView.subviews.first { $0 is TextInputView } as! TextInputView
        return (textView, inputView)
    }

    /// "foo foo\n": two "foo" occurrences at 0..3 and 4..7.
    func testTypingReplacesEverySelection() {
        let (textView, input) = makeTextView("foo foo\n")
        textView.selections = [NSRange(location: 0, length: 3), NSRange(location: 4, length: 3)]
        input.insertText("bar")
        XCTAssertEqual(textView.text, "bar bar\n")
        XCTAssertEqual(textView.selections, [NSRange(location: 3, length: 0), NSRange(location: 7, length: 0)],
                       "each replaced occurrence leaves a caret after the new text")
    }

    func testBackspaceDeletesTheSelectionOrTheCharacterBefore() {
        let (textView, input) = makeTextView("foo foo\n")
        textView.selections = [NSRange(location: 0, length: 3), NSRange(location: 4, length: 3)]
        input.deleteBackward()
        XCTAssertEqual(textView.text, " \n")
    }

    func testOneUndoRestoresEverySelection() {
        let (textView, input) = makeTextView("foo foo\n")
        textView.selections = [NSRange(location: 0, length: 3), NSRange(location: 4, length: 3)]
        input.insertText("bar")
        textView.undoManager?.undo()
        XCTAssertEqual(textView.text, "foo foo\n")
    }

    func testCaretsInsertAtEach() {
        let (textView, input) = makeTextView("foo foo\n")
        textView.selections = [NSRange(location: 1, length: 0), NSRange(location: 5, length: 0)]
        input.insertText("X")
        XCTAssertEqual(textView.text, "fXoo fXoo\n")
        XCTAssertEqual(textView.selections, [NSRange(location: 2, length: 0), NSRange(location: 7, length: 0)])
    }

    func testOverlappingSelectionsAreMerged() {
        let (textView, _) = makeTextView("foo foo\n")
        textView.selections = [NSRange(location: 0, length: 3), NSRange(location: 1, length: 3),
                               NSRange(location: 5, length: 2), NSRange(location: 5, length: 2)]
        XCTAssertEqual(textView.selections, [NSRange(location: 0, length: 3), NSRange(location: 5, length: 2)],
                       "the one overlapping the primary is dropped, the duplicates merged")
    }

    func testAnOrdinaryEditMovesTheSecondarySelections() {
        let (textView, _) = makeTextView("abcd ef\n")
        textView.selections = [NSRange(location: 0, length: 0), NSRange(location: 5, length: 2)]
        let start = textView.position(from: textView.beginningOfDocument, offset: 0)!
        textView.replace(textView.textRange(from: start, to: start)!, withText: "xx")
        XCTAssertEqual(textView.text, "xxabcd ef\n")
        XCTAssertEqual(textView.selections, [NSRange(location: 2, length: 0), NSRange(location: 7, length: 2)],
                       "the secondary selection moved by the inserted text")
    }

    func testSelectingAllAtOnceSendsOneSelectionChange() {
        let (textView, _) = makeTextView("foo foo\n")
        var changes = 0
        let delegate = CountingDelegate { changes += 1 }
        textView.editorDelegate = delegate
        textView.selections = [NSRange(location: 0, length: 3), NSRange(location: 4, length: 3)]
        XCTAssertEqual(changes, 1, "setting every selection is one notification")
        withExtendedLifetime(delegate) {}
    }
}

/// Counts selection changes (and ignores everything else).
private final class CountingDelegate: NSObject, TextViewDelegate {
    private let onChange: () -> Void
    init(_ onChange: @escaping () -> Void) { self.onChange = onChange }
    func textViewDidChangeSelection(_ textView: TextView) { onChange() }
}
