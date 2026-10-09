import UIKit

// Omnie-dev patch 0014: VoiceOver.
//
// - The editor is one accessibility element. Its value is the caret's line and column and that
//   line's text; VoiceOver's character/word/line navigation works through UITextInput.
// - UIAccessibilityReadingContent lets VoiceOver read the document line by line.
// - Decorations with an accessibility label (diagnostics, agent authorship) are read with their line
//   and reachable through a "Diagnostics" rotor that moves the caret to them.
extension TextInputView: UIAccessibilityReadingContent {
    override var isAccessibilityElement: Bool {
        get { true }
        set {}
    }

    override var accessibilityLabel: String? {
        get { super.accessibilityLabel ?? "Code editor" }
        set { super.accessibilityLabel = newValue }
    }

    override var accessibilityValue: String? {
        get {
            guard let selectedRange, let position = lineManager.linePosition(at: selectedRange.location) else { return nil }
            let line = accessibilityContent(forLineNumber: position.row) ?? ""
            return "Line \(position.row + 1), column \(position.column + 1). \(line)"
        }
        set {}
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { super.accessibilityTraits.union(.updatesFrequently) }
        set { super.accessibilityTraits = newValue }
    }

    override var accessibilityCustomRotors: [UIAccessibilityCustomRotor]? {
        get {
            [UIAccessibilityCustomRotor(name: "Diagnostics") { [weak self] predicate in
                self?.diagnosticsRotorResult(for: predicate)
            }]
        }
        set {}
    }

    // MARK: UIAccessibilityReadingContent

    func accessibilityLineNumber(for point: CGPoint) -> Int {
        let local = window.map { convert(point, from: $0.screen.coordinateSpace) } ?? point
        guard let line = lineManager.line(containingYOffset: local.y - textContainerInset.top) else { return NSNotFound }
        return line.index
    }

    func accessibilityContent(forLineNumber lineNumber: Int) -> String? {
        guard lineNumber >= 0 && lineNumber < lineManager.lineCount else { return nil }
        let line = lineManager.line(atRow: lineNumber)
        let range = NSRange(location: line.location, length: line.data.length)
        let text = stringView.substring(in: range) ?? ""
        let lineRange = NSRange(location: line.location, length: line.data.totalLength)
        let notes = decorations
            .filter { $0.accessibilityLabel != nil && NSIntersectionRange($0.range, lineRange).length > 0 || ($0.range.length == 0 && NSLocationInRange($0.range.location, lineRange)) }
            .compactMap { $0.accessibilityLabel }
        let spoken = text.isEmpty ? "Blank" : text
        return notes.isEmpty ? spoken : spoken + ". " + notes.joined(separator: ". ")
    }

    func accessibilityFrame(forLineNumber lineNumber: Int) -> CGRect {
        guard lineNumber >= 0 && lineNumber < lineManager.lineCount else { return .zero }
        let line = lineManager.line(atRow: lineNumber)
        let rect = CGRect(x: 0, y: line.yPosition + textContainerInset.top, width: bounds.width, height: line.data.lineHeight)
        return UIAccessibility.convertToScreenCoordinates(rect, in: self)
    }

    func accessibilityPageContent() -> String? {
        let visible = bounds.intersection(CGRect(origin: .zero, size: contentSize))
        guard let first = lineManager.line(containingYOffset: max(visible.minY - textContainerInset.top, 0)) else { return nil }
        let last = lineManager.line(containingYOffset: visible.maxY - textContainerInset.top) ?? lineManager.lastLine
        return (first.index ... last.index).compactMap { accessibilityContent(forLineNumber: $0) }.joined(separator: "\n")
    }

    // MARK: Diagnostics rotor

    private func diagnosticsRotorResult(for predicate: UIAccessibilityCustomRotorSearchPredicate) -> UIAccessibilityCustomRotorItemResult? {
        let labeled = decorations.filter { $0.accessibilityLabel != nil }
        guard !labeled.isEmpty else { return nil }
        let current = (predicate.currentItem.targetRange as? IndexedRange)?.range.location ?? selectedRange?.location ?? 0
        let target: Decoration?
        switch predicate.searchDirection {
        case .next: target = labeled.first { $0.range.location > current } ?? labeled.first
        case .previous: target = labeled.last { $0.range.location < current } ?? labeled.last
        @unknown default: target = nil
        }
        guard let target else { return nil }
        selectedRange = NSRange(location: target.range.location, length: 0)
        UIAccessibility.post(notification: .announcement, argument: target.accessibilityLabel)
        return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: IndexedRange(target.range))
    }
}
