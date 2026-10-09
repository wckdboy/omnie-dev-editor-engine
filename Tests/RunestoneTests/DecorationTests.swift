import XCTest
@testable import Runestone

/// Patch 0011: decorations follow edits and only visible ones are laid out.
@MainActor
final class DecorationTests: XCTestCase {
    private func deco(_ location: Int, _ length: Int) -> Decoration {
        Decoration(id: "d", range: NSRange(location: location, length: length), style: .squiggle(.red))
    }

    func testShiftAcrossEdits() {
        let d = deco(10, 5) // 10..<15
        XCTAssertEqual(d.shifted(byReplacing: NSRange(location: 2, length: 0), newLength: 3).range, NSRange(location: 13, length: 5), "insert before")
        XCTAssertEqual(d.shifted(byReplacing: NSRange(location: 20, length: 2), newLength: 0).range, NSRange(location: 10, length: 5), "delete after")
        XCTAssertEqual(d.shifted(byReplacing: NSRange(location: 12, length: 1), newLength: 4).range, NSRange(location: 10, length: 8), "edit inside")
        XCTAssertEqual(d.shifted(byReplacing: NSRange(location: 10, length: 0), newLength: 2).range, NSRange(location: 12, length: 5), "insert at start moves it")
        XCTAssertEqual(d.shifted(byReplacing: NSRange(location: 0, length: 12), newLength: 1).range, NSRange(location: 0, length: 4), "delete over start")
        XCTAssertEqual(d.shifted(byReplacing: NSRange(location: 10, length: 5), newLength: 0).range, NSRange(location: 10, length: 0), "delete all of it")
    }

    func testTypingMovesDecorationsInTheView() {
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        textView.text = "let alpha = beta;\n"
        textView.decorations = [Decoration(id: "beta", range: NSRange(location: 12, length: 4), style: .squiggle(.red))]
        textView.replace(NSRange(location: 0, length: 0), withText: "// x\n")
        XCTAssertEqual(textView.decorations.first?.range, NSRange(location: 17, length: 4))
    }

    func testOnlyVisibleDecorationsAreDrawn() throws {
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        textView.showLineNumbers = true
        textView.text = (0..<5000).map { "line \($0) with some words" }.joined(separator: "\n")
        textView.layoutIfNeeded()
        let near = NSRange(location: 5, length: 4)                  // line 0
        let farLocation = (textView.text as NSString).range(of: "line 4000 ").location
        textView.decorations = [
            Decoration(id: "near", range: near, style: .squiggle(.red)),
            Decoration(id: "bg", range: NSRange(location: 0, length: 4), style: .background(.green)),
            Decoration(id: "bar", range: NSRange(location: 0, length: 60), style: .gutterBar(.purple)),
            Decoration(id: "far", range: NSRange(location: farLocation, length: 4), style: .squiggle(.red)),
        ]
        textView.layoutIfNeeded()
        let inputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView })
        let views = inputView.subviews.compactMap { $0 as? DecorationView }
        XCTAssertEqual(views.count, 2, "background and foreground views")
        let foregroundItems = views.flatMap(\.items).filter { if case .squiggle = $0.style { true } else { false } }
        XCTAssertEqual(foregroundItems.count, 1, "only the visible squiggle is laid out")
        XCTAssertGreaterThan(foregroundItems[0].rect.width, 0)
        let gutterViews = textView.subviews.filter { !($0 is TextInputView) }
            .flatMap { $0.subviews }.compactMap { $0 as? DecorationView }
        let bar = try XCTUnwrap(gutterViews.flatMap(\.items).first)
        XCTAssertEqual(bar.rect.width, 3)
        XCTAssertGreaterThan(bar.rect.height, 30, "bar spans the lines the range touches")
    }
}
