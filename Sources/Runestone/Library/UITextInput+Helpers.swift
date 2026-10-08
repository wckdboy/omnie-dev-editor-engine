import UIKit

@available(iOS 17, *)
extension UIView {
    /// The selection display interaction that UITextInteraction installs on this view.
    /// Found through the public `interactions` array; no private API (Omnie-dev patch 0001).
    var sbs_textSelectionDisplayInteraction: UITextSelectionDisplayInteraction? {
        interactions.lazy.compactMap { $0 as? UITextSelectionDisplayInteraction }.first
    }
}
