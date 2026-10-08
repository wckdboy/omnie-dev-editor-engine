# Patches on top of Runestone

`omnie-dev-editor-engine` is a hard fork of [simonbs/Runestone](https://github.com/simonbs/Runestone) (MIT) for Omnie-dev's code editor (Omnie-dev PLAN §5.1). The `upstream` branch mirrors Runestone exactly; `main` is upstream plus the patches below, kept small and one topic each. Fixes worth sharing go upstream first.

| # | Patch | Why | Upstream status |
|---|---|---|---|
| 0001 | Remove private API: public `interactions` lookup for the selection display, public `UITextCursorView.isBlinking`, drop the `UITextReplacement` KVC autocorrect path and the `_UIScrollPocket` lookup | Spike test 11 (zero private selectors or KVC keys) and App Review | Not upstreamed (changes behavior: no autocorrect suggestion menu in code views) |
| 0002 | `UITextInput.text(in:)` returns `""` instead of `nil` for empty and end-of-buffer ranges; internal callers unchanged | iOS 26.1 Writing Tools crash on Return at end of buffer ([#413](https://github.com/simonbs/Runestone/issues/413)) | Candidate for upstream (narrower than the patch in #413) |
| 0003 | tree-sitter runtime 0.20.9 → 0.26.13. `TSLanguage` is opaque now, so `TreeSitterLanguage` takes `OpaquePointer` (public API change); `TSInputEncodingUTF16` → `UTF16LE`; `TSInput.decode = nil` | Current grammars are ABI 15, which 0.20 can't load. 0.26.13 is the newest release that still ships a `Package.swift` (0.27 dropped it) | Overlaps upstream PR #428 (0.23–0.25) |

Fork base: Runestone 0.5.2 (`592434a`, 25 Mar 2026).
