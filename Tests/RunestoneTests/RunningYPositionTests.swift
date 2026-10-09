import XCTest
@testable import Runestone

/// Patch 0009 carries y-positions forward during layout instead of asking the tree for each line.
/// After layout, every visible line's tree y-position must equal the sum of the heights above it.
@MainActor
final class RunningYPositionTests: XCTestCase {
    func testVisibleLinePositionsMatchTreeAfterLayout() throws {
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        textView.isLineWrappingEnabled = true
        textView.text = (0..<400).map { i in String(repeating: "word ", count: i % 37) }.joined(separator: "\n")
        textView.layoutIfNeeded()
        textView.contentOffset = CGPoint(x: 0, y: 3000)
        textView.layoutIfNeeded()
        let inputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView } as? TextInputView)
        let lineManager = inputView.lineManager
        var sum: CGFloat = 0
        for row in 0 ..< lineManager.lineCount {
            let line = lineManager.line(atRow: row)
            XCTAssertEqual(line.yPosition, sum, accuracy: 0.001, "row \(row)")
            sum += line.data.lineHeight
        }
    }
}
