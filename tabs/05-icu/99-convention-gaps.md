# ICU inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory of presentation code (2026-08-11).

## Residual

1. **Counts not authoritative totals** — active / critical / transfers / discharge / ended derive from current page `board.items`, not dedicated server scope totals / filtered query totals (`tabs.mdc` counts).
2. **Filters are client-only on the current page** — Apply does not reload scope / refresh sibling tab counts (`tabs.mdc` tab↔table↔filters sync).
3. **No date filters** on ICU board Advanced filters (`tables.mdc`).
4. **No table Export** on patient boards (`tables.mdc` toolbar).
5. **No table Print** — print only inside stay detail (`tables.mdc` / `printing.mdc`).
6. **Follow-ups Filters omitted** on ICU host (`showAdvancedFilterButton: false`).
7. **Bed board** has no Filters / Settings / Export / Print; count is all-beds length (not ward-filtered).
8. **Shared column storage** `'icu_board'` across all patient sections.
9. **URL sync on tab change** drops search / `id` / `panel` (only `section`).
10. **Route entry mismatch** — `AppRoutes.icu` ∪ clinical|emergency|operations:read vs `RouteAccessCatalog.icuEntry` ∩ `icu:read`.
