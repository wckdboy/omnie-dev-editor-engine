import XCTest
@testable import Runestone

/// Character-pair auto-close (Runestone's `characterPairs`): typing an opening bracket or quote
/// inserts its partner, typing the closer skips over one already there, and a selection is wrapped.
@MainActor
final class CharacterPairTests: XCTestCase {
    private struct Pair: CharacterPair {
        let leading: String
        let trailing: String
    }

    private func makeTextView(_ text: String) -> (TextView, TextInputView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let textView = TextView(frame: window.bounds)
        window.addSubview(textView)
        textView.text = text
        textView.characterPairs = [Pair(leading: "(", trailing: ")"), Pair(leading: "[", trailing: "]"),
                                   Pair(leading: "{", trailing: "}"), Pair(leading: "\"", trailing: "\""),
                                   Pair(leading: "'", trailing: "'"), Pair(leading: "`", trailing: "`")]
        let inputView = textView.subviews.first { $0 is TextInputView } as! TextInputView
        return (textView, inputView)
    }

    func testTypingAnOpeningBracketInsertsThePair() {
        let (textView, input) = makeTextView("")
        textView.selectedRange = NSRange(location: 0, length: 0)
        input.insertText("(")
        XCTAssertEqual(textView.text, "()")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 1, length: 0))
    }

    func testTypingAQuoteInsertsThePairThenSkipsOverIt() {
        let (textView, input) = makeTextView("")
        textView.selectedRange = NSRange(location: 0, length: 0)
        input.insertText("\"")
        XCTAssertEqual(textView.text, "\"\"")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 1, length: 0))
        input.insertText("\"")
        XCTAssertEqual(textView.text, "\"\"", "the second quote skips over the one already there")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 0))
    }

    func testTypingOverASelectionWrapsIt() {
        let (textView, input) = makeTextView("word")
        textView.selectedRange = NSRange(location: 0, length: 4)
        input.insertText("(")
        XCTAssertEqual(textView.text, "(word)")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 1, length: 4), "the selection stays inside")
    }

    func testTypingAnOpeningBracketBeforeItsCloserDoesNotDouble() {
        let (textView, input) = makeTextView(")")
        textView.selectedRange = NSRange(location: 0, length: 0)
        input.insertText("(")
        XCTAssertEqual(textView.text, "()", "the ) already there is the partner, not a second one")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 1, length: 0))
    }
}
