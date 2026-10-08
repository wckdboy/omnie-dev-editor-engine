# Patches on top of Runestone

`omnie-dev-editor-engine` is a hard fork of [simonbs/Runestone](https://github.com/simonbs/Runestone) (MIT) for Omnie-dev's code editor (Omnie-dev PLAN §5.1). The `upstream` branch mirrors Runestone exactly; `main` is upstream plus the patches below, kept small and one topic each. Fixes worth sharing go upstream first.

| # | Patch | Why | Upstream status |
|---|---|---|---|
| 0001 | Remove private API: public `interactions` lookup for the selection display, public `UITextCursorView.isBlinking`, drop the `UITextReplacement` KVC autocorrect path and the `_UIScrollPocket` lookup | Spike test 11 (zero private selectors or KVC keys) and App Review | Not upstreamed (changes behavior: no autocorrect suggestion menu in code views) |

Fork base: Runestone 0.5.2 (`592434a`, 25 Mar 2026).
