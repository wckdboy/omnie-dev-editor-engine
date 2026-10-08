import XCTest
@testable import Runestone
import TestTreeSitterLanguages

/// Patch 0007: edits reparse on a background queue; the new tree must arrive and reflect the edit.
@MainActor
final class BackgroundReparseTests: XCTestCase {
    func testEditIsReparsedInBackgroundAndReachesTheView() throws {
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        // No injections query, so the root layer takes the background path.
        let language = TreeSitterLanguage(OpaquePointer(tree_sitter_javascript()))
        let state = TextViewState(text: "let a = 1;\n", language: language)
        textView.setState(state)
        XCTAssertEqual(textView.syntaxNode(at: 8)?.type, "number")

        textView.replace(NSRange(location: 8, length: 1), withText: "\"s\"")

        let deadline = Date().addingTimeInterval(2)
        while textView.syntaxNode(at: 9)?.type != "string_fragment" && textView.syntaxNode(at: 9)?.type != "string",
              Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        let type = textView.syntaxNode(at: 9)?.type
        XCTAssertTrue(type == "string" || type == "string_fragment", "node after reparse: \(type ?? "nil")")
    }
}
