# ICU inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after shared-chrome + per-tab remediation.

## Residual

none

## Closed (2026-08-12)

Shared chrome and desk tabs closed the former residual list:

1. Authoritative counts via `IcuScopeCounts` / server `totalItemCount` (not page `items.length` alone)
2. Sibling model = dedicated unfiltered scope totals; active tab badge uses filtered membership when narrowed
3. Patient-board Advanced filters include admitted-at date range
4. Table Export on patient / bed / follow-ups boards (`canExport` ∩ `evidence:export`)
5. Table Print after Export (preview-first); stay-detail Print label `Print`
6. Follow-ups Filters enabled on ICU host (`showAdvancedFilterButton: true`)
7. Bed board Filters / Settings / Export / Print; badge tracks `visibleBeds`
8. Per-section column storage `icu_${section.name}` / `icu_cw_${section.name}` (beds / follow-ups keyed separately)
9. URL sync preserves `search` / `id` / `panel` with `section`
10. Route entry aligned: `AppRoutes.icu` + `RouteAccessCatalog.icuEntry` ∩ `icu:read` + module

Regression coverage: `frontend/test/features/icu/presentation/icu_workspace_page_test.dart`, per-tab permissions/chrome tests, `icuRouteEntryMatchesAppRoutes()`.
