import XCTest
@testable import Runestone

/// Patch 0016: folded lines take no space, move with edits, and unfold when edited.
@MainActor
final class FoldingTests: XCTestCase {
    private func makeView(_ text: String) -> TextView {
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        textView.showLineNumbers = true
        textView.text = text
        textView.layoutIfNeeded()
        return textView
    }

    /// The range of whole lines `first...last` (0-based rows), newline included.
    private func lines(_ text: String, _ first: Int, _ last: Int) -> NSRange {
        let ns = text as NSString
        var starts = [0]
        for i in 0..<ns.length where ns.character(at: i) == 10 { starts.append(i + 1) }
        let end = last + 1 < starts.count ? starts[last + 1] : ns.length
        return NSRange(location: starts[first], length: end - starts[first])
    }

    func testFoldedLinesTakeNoSpace() throws {
        let text = (0..<40).map { "line \($0)" }.joined(separator: "\n")
        let textView = makeView(text)
        let full = textView.contentSize.height
        textView.foldedRanges = [lines(text, 5, 24)]
        textView.layoutIfNeeded()
        let folded = textView.contentSize.height
        XCTAssertLessThan(folded, full * 0.6, "20 of 40 lines hidden")
        XCTAssertGreaterThan(folded, full * 0.4)
        // No line numbers for the hidden rows: "6" (row 5) is gone, "26" (row 25) shows.
        func allLabels(_ view: UIView) -> [UILabel] {
            ((view as? UILabel).map { [$0] } ?? []) + view.subviews.flatMap(allLabels)
        }
        // Reused line number views park far offscreen.
        let labels = allLabels(textView).filter { ($0.superview?.frame.minY ?? 0) > -1000 }.compactMap(\.text)
        XCTAssertFalse(labels.contains("6"), "\(labels)")
        XCTAssertTrue(labels.contains("5") && labels.contains("26"), "\(labels)")
        // Row 25 sits right below row 4 now.
        func caret(_ needle: String) throws -> CGRect {
            let position = try XCTUnwrap(textView.position(from: textView.beginningOfDocument, offset: (text as NSString).range(of: needle).location))
            return textView.caretRect(for: position)
        }
        let row4 = try caret("line 4\n")
        let row25 = try caret("line 25")
        XCTAssertEqual(row25.minY - row4.minY, row4.height, accuracy: row4.height * 0.4)

        textView.foldedRanges = []
        textView.layoutIfNeeded()
        XCTAssertEqual(textView.contentSize.height, full, accuracy: 1, "unfolding gives the space back")
    }

    func testFoldsMoveWithEditsAndUnfoldWhenEdited() {
        let text = "a\nb\nc\nd\ne\n"
        let textView = makeView(text)
        let fold = NSRange(location: 4, length: 4)          // "c\nd\n"
        textView.foldedRanges = [fold]
        textView.replace(NSRange(location: 0, length: 0), withText: "zz\n")
        XCTAssertEqual(textView.foldedRanges, [NSRange(location: 7, length: 4)], "an edit above moves it")
        textView.replace(NSRange(location: 12, length: 0), withText: "!")
        XCTAssertEqual(textView.foldedRanges, [NSRange(location: 7, length: 4)], "an edit below leaves it")
        textView.replace(NSRange(location: 8, length: 0), withText: "x")
        XCTAssertEqual(textView.foldedRanges, [], "an edit inside unfolds it")
    }
}
