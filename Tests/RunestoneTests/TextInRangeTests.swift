import XCTest
@testable import Runestone

/// Patch 0002 (#413): UITextInput.text(in:) must not return nil for empty or end-of-buffer ranges.
@MainActor
final class TextInRangeTests: XCTestCase {
    func testEmptyRangeAtEndOfBufferIsEmptyStringNotNil() throws {
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        textView.text = "hello\n"
        let inputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView } as? TextInputView)
        let end = IndexedRange(location: 6, length: 0)
        XCTAssertEqual(inputView.text(in: end as UITextRange), "")
        XCTAssertEqual(inputView.text(in: IndexedRange(location: 0, length: 5) as UITextRange), "hello")
    }
}
