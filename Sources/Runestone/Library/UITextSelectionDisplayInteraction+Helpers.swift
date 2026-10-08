import UIKit

@available(iOS 17, *)
extension UITextSelectionDisplayInteraction {
    func sbs_enableCursorBlinks() {
        // Public since iOS 17 via UITextCursorView (Omnie-dev patch 0001).
        cursorView.isBlinking = true
    }
}
