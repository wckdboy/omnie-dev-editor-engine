import XCTest
@testable import Runestone

/// Omnie-dev patch 0001 replaced a private-API walk with a public lookup. This checks the public
/// lookup still finds the selection display interaction UITextInteraction installs.
@MainActor
final class PublicSelectionDisplayTests: XCTestCase {
    func testSelectionDisplayInteractionIsReachableThroughPublicAPI() throws {
        guard #available(iOS 17, *) else { throw XCTSkip("needs iOS 17") }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let textView = TextView(frame: window.bounds)
        window.addSubview(textView)
        window.makeKeyAndVisible()
        textView.text = "let x = 1\n"
        XCTAssertTrue(textView.becomeFirstResponder())
        textView.layoutIfNeeded()
        let inputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView })
        let interactions = inputView.interactions.map { String(describing: type(of: $0)) }
        XCTAssertNotNil(inputView.sbs_textSelectionDisplayInteraction,
                        "interactions on the input view: \(interactions)")
    }
}
