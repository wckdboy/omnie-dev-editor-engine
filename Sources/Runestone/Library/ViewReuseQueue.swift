import UIKit

protocol ReusableView {
    func prepareForReuse()
}

extension ReusableView {
    func prepareForReuse() {}
}

final class ViewReuseQueue<Key: Hashable, View: UIView & ReusableView> {
    private(set) var visibleViews: [Key: View] = [:]

    private var queuedViews: Set<View> = []

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemory),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func enqueueViews(withKeys keys: Set<Key>) {
        for key in keys {
            if let view = visibleViews.removeValue(forKey: key) {
                view.prepareForReuse()
                queueViewIfNeeded(view)
            }
        }
    }

    func dequeueView(forKey key: Key) -> View {
        if let view = visibleViews[key] {
            return view
        } else if !queuedViews.isEmpty {
            let view = queuedViews.removeFirst()
            visibleViews[key] = view
            return view
        } else {
            let view = View()
            visibleViews[key] = view
            return view
        }
    }

    // Omnie-dev patch 0005: queued views stay in the hierarchy, parked offscreen, instead of being
    // removed and re-added (or hidden). Adding, removing and hiding subviews all make UIKit re-run focus
    // and view-visitor bookkeeping for every line that scrolls in or out, which dominated scroll time
    // in profiling; a frame change doesn't. The queue may also hold as many views as are visible (was a
    // quarter), so a fast fling reuses views instead of allocating new ones every frame. A memory
    // warning still drops them. Layout sets a dequeued view's frame before it's shown.
    private static var parkedOrigin: CGPoint { CGPoint(x: -100_000, y: -100_000) }

    private func queueViewIfNeeded(_ view: View) {
        if queuedViews.count < max(visibleViews.count, 16) {
            view.frame.origin = Self.parkedOrigin
            queuedViews.insert(view)
        } else {
            view.removeFromSuperview()
        }
    }

    @objc private func clearMemory() {
        for view in queuedViews { view.removeFromSuperview() }
        queuedViews.removeAll()
    }
}
