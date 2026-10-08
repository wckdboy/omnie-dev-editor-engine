import Foundation

final class TreeSitterLanguageLayer {
    typealias LayerAndNodeTuple = (layer: TreeSitterLanguageLayer, node: TreeSitterNode)

    let language: TreeSitterInternalLanguage
    private(set) var tree: TreeSitterTree?
    var canHighlight: Bool {
        parser.language != nil && tree != nil
    }

    private let lineManager: LineManager
    private let parser: TreeSitterParser
    private let stringView: StringView
    private var childLanguageLayerStore = TreeSitterLanguageLayerStore()
    private weak var parentLanguageLayer: TreeSitterLanguageLayer?
    private let languageProvider: TreeSitterLanguageProvider?

    // Patch 0007: incremental reparse off the main thread. Edits are applied to the tree on the main
    // thread (cheap, keeps node positions correct); the reparse runs on a serial queue against an
    // immutable snapshot of the text with its own parser, then the new tree and the changed lines come
    // back to the main thread. If more edits arrived meanwhile, the result is dropped and the next
    // parse starts from the latest text. Layers with injections keep the synchronous path.
    var onBackgroundReparse: ((LineChangeSet) -> Void)?
    private static let parseQueue = DispatchQueue(label: "omnie.editor.tree-sitter.parse", qos: .userInitiated)
    private lazy var backgroundParser = TreeSitterParser(encoding: parser.encoding)
    private var editGeneration = 0
    private var isBackgroundParsing = false
    private var canParseInBackground: Bool {
        onBackgroundReparse != nil && parentLanguageLayer == nil && language.injectionsQuery == nil
            && childLanguageLayerStore.allLayers.isEmpty && tree != nil
    }

    private var isEmpty: Bool {
        if let rootNode = tree?.rootNode {
            return rootNode.endByte - rootNode.startByte <= ByteCount(0)
        } else {
            return true
        }
    }

    init(language: TreeSitterInternalLanguage,
         languageProvider: TreeSitterLanguageProvider?,
         parser: TreeSitterParser,
         stringView: StringView,
         lineManager: LineManager) {
        self.language = language
        self.languageProvider = languageProvider
        self.parser = parser
        self.stringView = stringView
        self.lineManager = lineManager
    }
}

// MARK: - Parsing
extension TreeSitterLanguageLayer {
    func parse(_ text: NSString) {
        let ranges = [tree?.rootNode.textRange].compactMap { $0 }
        parse(ranges, from: text)
    }

    func apply(_ edit: TreeSitterInputEdit) -> LineChangeSet {
        let ranges = [tree?.rootNode.textRange].compactMap { $0 }
        return apply(edit, parsing: ranges)
    }

    func layerAndNode(at linePosition: LinePosition) -> LayerAndNodeTuple? {
        let point = TreeSitterTextPoint(linePosition)
        guard let node = tree?.rootNode.descendantForRange(from: point, to: point) else {
            return nil
        }
        var result: LayerAndNodeTuple = (layer: self, node: node)
        for childLanguageLayer in childLanguageLayerStore.allLayers {
            if let childRootNode = childLanguageLayer.tree?.rootNode, childRootNode.contains(point) {
                if let childResult = childLanguageLayer.layerAndNode(at: linePosition) {
                    if childResult.node.byteRange.length < result.node.byteRange.length {
                        result = childResult
                    }
                }
            }
        }
        return result
    }

    private func apply(_ edit: TreeSitterInputEdit, parsing ranges: [TreeSitterTextRange] = []) -> LineChangeSet {
        if canParseInBackground {
            tree?.apply(edit)
            editGeneration += 1
            scheduleBackgroundParse()
            // The edited lines themselves are already in the text edit's change set.
            return LineChangeSet()
        }
        // Apply edit to tree.
        let oldTree = tree
        tree?.apply(edit)
        prepareParser(toParse: ranges)
        tree = parser.parse(oldTree: tree)
        // Gather changed lines.
        let lineChangeSet = LineChangeSet()
        if let oldTree = oldTree, let newTree = tree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            for changedRange in changedRanges {
                let startRow = Int(changedRange.startPoint.row)
                let endRow = Int(changedRange.endPoint.row)
                for row in startRow ... endRow {
                    let line = lineManager.line(atRow: row)
                    lineChangeSet.markLineEdited(line)
                }
            }
        }
        let childLineChangeSet = updateChildLayers(applying: edit)
        lineChangeSet.union(with: childLineChangeSet)
        return lineChangeSet
    }

    private func scheduleBackgroundParse() {
        guard !isBackgroundParsing, let tree else { return }
        isBackgroundParsing = true
        let generation = editGeneration
        // An immutable snapshot: the parser must never read the live, mutable string from another thread.
        let snapshot = stringView.string.copy() as! NSString
        let oldTree = tree.copy()
        let parser = backgroundParser
        parser.language = language.languagePointer
        parser.removeAllIncludedRanges()
        Self.parseQueue.async { [weak self] in
            let newTree = snapshot.length > 0 ? parser.parse(snapshot, oldTree: oldTree) : nil
            let changedRanges = newTree.map { oldTree.rangesChanged(comparingTo: $0) } ?? []
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBackgroundParsing = false
                guard generation == self.editGeneration else {
                    self.scheduleBackgroundParse()
                    return
                }
                self.tree = newTree
                let lineChangeSet = LineChangeSet()
                for changedRange in changedRanges {
                    let startRow = Int(changedRange.startPoint.row)
                    let endRow = Int(changedRange.endPoint.row)
                    for row in startRow ... endRow where row < self.lineManager.lineCount {
                        lineChangeSet.markLineEdited(self.lineManager.line(atRow: row))
                    }
                }
                self.onBackgroundReparse?(lineChangeSet)
            }
        }
    }

    private func prepareParser(toParse ranges: [TreeSitterTextRange]) {
        parser.language = language.languagePointer
        if !ranges.isEmpty && parentLanguageLayer != nil {
            parser.setIncludedRanges(ranges)
        } else {
            parser.removeAllIncludedRanges()
        }
    }

    private func parse(_ ranges: [TreeSitterTextRange], from text: NSString) {
        prepareParser(toParse: ranges)
        tree = parser.parse(text)
        childLanguageLayerStore.removeAll()
        guard let injectionsQuery = language.injectionsQuery, let node = tree?.rootNode else {
            return
        }
        let queryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
        queryCursor.execute()
        let captures = queryCursor.validCaptures(in: stringView)
        let injectedLanguages = injectedLanguages(from: captures)
        for injectedLanguage in injectedLanguages {
            if let childLanguageLayer = childLanguageLayer(withID: injectedLanguage.id, forLanguageNamed: injectedLanguage.languageName) {
                childLanguageLayer.parse([injectedLanguage.textRange], from: text)
            }
        }
    }
}

// MARK: - Syntax Highlighting
extension TreeSitterLanguageLayer {
    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        guard !range.isEmpty else {
            return []
        }
        var captures = allValidCaptures(in: range)
        captures.sort(by: TreeSitterCapture.captureLayerSorting)
        return captures
    }

    private func allValidCaptures(in range: ByteRange) -> [TreeSitterCapture] {
        guard let tree = tree else {
            return []
        }
        guard let highlightsQuery = language.highlightsQuery else {
            return []
        }
        let queryCursor = TreeSitterQueryCursor(query: highlightsQuery, node: tree.rootNode)
        queryCursor.setQueryRange(range)
        queryCursor.execute()
        let captures = queryCursor.validCaptures(in: stringView)
        let capturesInChildren = childLanguageLayerStore.allLayers.reduce(into: []) { $0 += $1.allValidCaptures(in: range) }
        return captures + capturesInChildren
    }
}

// MARK: - Child Language Layers
private extension TreeSitterLanguageLayer {
    @discardableResult
    private func childLanguageLayer(withID id: UnsafeRawPointer, forLanguageNamed languageName: String) -> TreeSitterLanguageLayer? {
        if let childLanguageLayer = childLanguageLayerStore.layer(forKey: id) {
            return childLanguageLayer
        } else if let language = languageProvider?.treeSitterLanguage(named: languageName) {
            let childLanguageLayer = TreeSitterLanguageLayer(
                language: language.internalLanguage,
                languageProvider: languageProvider,
                parser: parser,
                stringView: stringView,
                lineManager: lineManager)
            childLanguageLayer.parentLanguageLayer = self
            childLanguageLayerStore.storeLayer(childLanguageLayer, forKey: id)
            return childLanguageLayer
        } else {
            return nil
        }
    }

    private func updateChildLayers(applying edit: TreeSitterInputEdit) -> LineChangeSet {
        guard let injectionsQuery = language.injectionsQuery, let node = tree?.rootNode else {
            childLanguageLayerStore.removeAll()
            return LineChangeSet()
        }
        let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
        injectionsQueryCursor.execute()
        let captures = injectionsQueryCursor.validCaptures(in: stringView)
        let injectedLanguages = injectedLanguages(from: captures)
        let capturedIDs = injectedLanguages.map(\.id)
        let currentIDs = childLanguageLayerStore.allIDs
        for id in currentIDs {
            if !capturedIDs.contains(id) {
                // Remove languages that we no longer have any captures for.
                childLanguageLayerStore.removeLayer(forKey: id)
            } else if let rootNode = childLanguageLayerStore.layer(forKey: id)?.tree?.rootNode, rootNode.byteRange.length <= 0 {
                // Remove layers that no longer have any content.
                childLanguageLayerStore.removeLayer(forKey: id)
            }
        }
        // Update layers for current captures.
        let lineChangeSet = LineChangeSet()
        for injectedLanguage in injectedLanguages {
            if let childLanguageLayer = childLanguageLayer(withID: injectedLanguage.id, forLanguageNamed: injectedLanguage.languageName) {
                let childLineChangeSet = childLanguageLayer.apply(edit, parsing: [injectedLanguage.textRange])
                lineChangeSet.union(with: childLineChangeSet)
            }
        }
        return lineChangeSet
    }

    private func injectedLanguages(from captures: [TreeSitterCapture]) -> [TreeSitterInjectedLanguage] {
        let mapper = TreeSitterInjectedLanguageMapper(captures: captures)
        mapper.delegate = self
        return mapper.map()
    }
}

// MARK: - TreeSitterInjectedLanguageMapperDelegate
extension TreeSitterLanguageLayer: TreeSitterInjectedLanguageMapperDelegate {
    func treeSitterInjectedLanguageMapper(_ mapper: TreeSitterInjectedLanguageMapper, textIn textRange: TreeSitterTextRange) -> String? {
        let byteRange = ByteRange(from: textRange.startByte, to: textRange.endByte)
        let range = NSRange(byteRange)
        return stringView.substring(in: range)
    }
}

// MARK: - Debugging Language Layers
extension TreeSitterLanguageLayer {
    func languageHierarchyStringRepresentation() -> String {
        var str = ""
        if let rootNode = tree?.rootNode {
            str += "● [\(rootNode.byteRange.lowerBound) - \(rootNode.byteRange.upperBound)]"
        } else {
            str += "●"
        }
        if !childLanguageLayerStore.isEmpty {
            str += "\n"
            str += childLanguageHierarchy(indent: 1)
        }
        return str
    }

    private func childLanguageHierarchy(indent: Int) -> String {
        var str = ""
        let languageIDs = childLanguageLayerStore.allIDs
        for (idx, languageID) in languageIDs.enumerated() {
            let indentStr = String(repeating: "  ", count: indent)
            let childLanguageLayer = childLanguageLayerStore.layer(forKey: languageID)!
            if let rootNode = childLanguageLayer.tree?.rootNode {
                str += indentStr + "\(languageID) [\(rootNode.byteRange.lowerBound) - \(rootNode.byteRange.upperBound)]"
            } else {
                str += indentStr + "\(languageID)"
            }
            if !childLanguageLayer.childLanguageLayerStore.isEmpty {
                str += "\n"
                str += childLanguageLayer.childLanguageHierarchy(indent: indent + 1)
            }
            if idx < languageIDs.count - 1 {
                str += indentStr + "\n"
            }
        }
        return str
    }
}

extension TreeSitterLanguageLayer: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterLanguageLayer node=\(tree?.rootNode.debugDescription ?? "") childLanguageLayers=\(childLanguageLayerStore)]"
    }
}

private extension TreeSitterCapture {
    static func captureLayerSorting(_ lhs: TreeSitterCapture, _ rhs: TreeSitterCapture) -> Bool {
        // We sort the captures by three parameters:
        // 1. The location. Captures that are early in the text should be sorted first.
        // 2. The length of the capture. If two captures start at the same location, then we sort the longest capture first.
        //    Short captures that start at that location adds another "layer" of capturing on top of a previous capture.
        // 3. The number of components in the name. E.g. "variable.builtin" is sorted after "variable" as the styling of "variable.builtin"
        //    should be applied after applying the styling of "variable", since it's a specialization.
        if lhs.byteRange.location < rhs.byteRange.location {
            return true
        } else if lhs.byteRange.location > rhs.byteRange.location {
            return false
        } else if lhs.byteRange.length > rhs.byteRange.length {
            return true
        } else if lhs.byteRange.length < rhs.byteRange.length {
            return false
        } else {
            return lhs.nameComponentCount < rhs.nameComponentCount
        }
    }
}

private extension TreeSitterNode {
    func contains(_ point: TreeSitterTextPoint) -> Bool {
        let containsStart = point.row > startPoint.row || (point.row == startPoint.row && point.column >= startPoint.column)
        let containsEnd = point.row < endPoint.row || (point.row == endPoint.row && point.column <= endPoint.column)
        return containsStart && containsEnd
    }
}
