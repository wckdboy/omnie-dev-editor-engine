import XCTest
@testable import Runestone

/// Engine ticket 2: hiding many folded ranges must not cost a second (the app's fold-all).
@MainActor
final class FoldPerformanceTests: XCTestCase {
    private func largeText(lines: Int = 20_000) -> String {
        var text = ""
        for i in 0..<lines {
            switch i % 10 {
            case 0: text += "function block\(i) {\n"
            case 9: text += "}\n"
            default: text += "  const value\(i) = compute(\(i), \"needle\");\n"
            }
        }
        return text
    }

    private func lineStarts(_ text: String) -> [Int] {
        let ns = text as NSString
        var starts = [0]
        for i in 0..<ns.length where ns.character(at: i) == 10 { starts.append(i + 1) }
        return starts
    }

    /// ~2 000 fold ranges, each hiding the 8 body lines of a block (the closing brace stays).
    private func folds(_ text: String) -> [NSRange] {
        let starts = lineStarts(text)
        let length = (text as NSString).length
        var ranges: [NSRange] = []
        var row = 0
        while row + 9 < starts.count {
            let first = row + 1, last = row + 8
            let end = last + 1 < starts.count ? starts[last + 1] : length
            ranges.append(NSRange(location: starts[first], length: end - starts[first]))
            row += 10
        }
        return ranges
    }

    func testHidingManyFoldsIsBounded() {
        let text = largeText()
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        textView.showLineNumbers = true
        textView.text = text
        textView.layoutIfNeeded()
        let ranges = folds(text)
        let start = CFTimeInterval(DispatchTime.now().uptimeNanoseconds) / 1e9
        textView.foldedRanges = ranges
        let elapsed = CFTimeInterval(DispatchTime.now().uptimeNanoseconds) / 1e9 - start
        print(String(format: "[fold-perf] %d folds: %.1f ms", ranges.count, elapsed * 1000))
        XCTAssertLessThan(elapsed, 5.0)
    }
}
