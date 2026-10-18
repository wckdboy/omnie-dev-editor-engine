import XCTest
import TestTreeSitterLanguages
@testable import Runestone

/// Smart indent: a line break continues a block, and a break between an opening and closing bracket
/// expands into a two-line block. (The engine's tree-sitter indent controller does this; the app only
/// has to tell it the file's indent and the grammar's indentation scopes.)
@MainActor
final class SmartIndentTests: XCTestCase {
    private func makeTextView(_ text: String,
                              grammar: OpaquePointer = OpaquePointer(tree_sitter_javascript()),
                              scopes: TreeSitterIndentationScopes = TreeSitterIndentationScopes(indent: ["statement_block"],
                                                                                                outdent: ["else", "}", "]"])) async -> (TextView, TextInputView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let textView = TextView(frame: window.bounds)
        window.addSubview(textView)
        textView.text = text
        textView.indentStrategy = .space(length: 2)
        let language = TreeSitterLanguage(grammar, indentationScopes: scopes)
        await withCheckedContinuation { continuation in
            textView.setLanguageMode(TreeSitterLanguageMode(language: language)) { _ in continuation.resume() }
        }
        let inputView = textView.subviews.first { $0 is TextInputView } as! TextInputView
        return (textView, inputView)
    }

    func testLineBreakAfterAnOpeningBraceIndents() async {
        let (textView, input) = await makeTextView("if (x) {\n  y();\n}\n")
        textView.selectedRange = NSRange(location: 8, length: 0)   // end of "if (x) {"
        input.insertText("\n")
        XCTAssertEqual(textView.text, "if (x) {\n  \n  y();\n}\n")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 11, length: 0))
    }

    func testLineBreakBetweenBracesExpandsToABlock() async {
        let (textView, input) = await makeTextView("if (x) {}")
        textView.selectedRange = NSRange(location: 8, length: 0)   // between { and }
        input.insertText("\n")
        XCTAssertEqual(textView.text, "if (x) {\n  \n}")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 11, length: 0))
    }

    func testLineBreakKeepsASiblingLinesIndent() async {
        let (textView, input) = await makeTextView("function f() {\n  a();\n}\n")
        textView.selectedRange = NSRange(location: 21, length: 0)  // end of "  a();"
        input.insertText("\n")
        XCTAssertEqual(textView.text, "function f() {\n  a();\n  \n}\n")
    }
}
