# Task: Fix Pharmacy "Catalog and stock" dialog + default queue filter

## Goal

On the Pharmacy workspace (`/pharmacy`), fix two issues:

1. **Catalog and stock dialog** — clicking the toolbar button must reliably open the dialog; the page must not become inactive with no visible dialog.
2. **Default queue filter** — the worklist should load with **All fields** (no status filter) instead of **Ready**, so all pharmacy orders are shown by default.

## Observed behavior (from screenshots)

| Issue | What happens |
|-------|----------------|
| Catalog dialog | Clicking **Catalog and stock** dims/blocks the page (modal barrier) but the dialog does not appear. A full page refresh restores interactivity; the dialog may work again after refresh. |
| Queue filter | **Queue filter → Queue status** defaults to **Ready**. With no matching orders, the table shows the empty state (*"No pharmacy orders"*). User expects **All fields** so the full queue is visible on first load. |

## Target files

**Catalog dialog fix (shared + pharmacy):**

- `frontend/lib/shared/components/app_dialog.dart` — dialog shell, `showAppDialog`, sizing/visibility
- `frontend/lib/shared/layout/app_dialog_insets.dart` — inset/sizing for normal and maximized modes
- `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart` — `openPharmacyCatalogDialog`
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` — `prepareCatalogTab` / catalog data refresh

**Default filter fix (pharmacy):**

- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` — `PharmacyWorkbenchQuery` default, `isDefaultFilters`, `fromChip`
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` — `_loadInitialState`
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` — `_pharmacyFilterValue`, `_pharmacyQueryFromFilterValue`, filter UI wiring

## Root-cause hints

### Catalog dialog

- `openPharmacyCatalogDialog` calls `showAppDialog` with `AppDialog(initialMaximized: false, maxWidth: 1080)`.
- If controller state is null, a loading `AppDialog` is shown; if state never resolves or the dialog is sized/positioned off-screen or behind the barrier, the user sees only an inactive page.
- Investigate whether a failed/pending `pharmacyWorkspaceControllerProvider` state, dialog layout (insets, zero size, off-viewport position), or focus/barrier handling prevents the dialog from rendering.
- Fix at the **shared dialog layer** where possible; avoid one-off pharmacy patches unless the bug is pharmacy-specific.

### Default filter

- `PharmacyWorkbenchQuery()` currently defaults to `status: 'ORDERED'`, which maps to **Ready** in the queue filter UI.
- `PharmacyOrderFilter.all` correctly uses `status: null` (all statuses).
- `_pharmacyQueryFromFilterValue` falls back with `status: status ?? 'ORDERED'`, which can re-apply **Ready** when clearing filters — align this with **All fields** semantics (`status: null`).
- Update `isDefaultFilters` so the new unfiltered default is not treated as an active filter.

## Expected behavior

### Catalog and stock

- Clicking **Catalog and stock** (toolbar or overflow menu) always opens a visible, interactive **Catalog and stock** dialog.
- The modal barrier appears **with** the dialog; closing the dialog or pressing Escape restores page interactivity.
- Dialog works on first visit without requiring a page refresh.
- Existing catalog tabs (drugs, inventory, storage) and maximize/resize/close behavior remain intact.

### Queue filter default

- On initial Pharmacy page load, **Queue status** shows **All fields** (no status chip selected).
- The worklist query uses `status: null` and returns orders across all statuses (subject only to search/pagination).
- **Clear filters** resets queue status to **All fields**, not **Ready**.
- Quick-filter chips (e.g. summary notifications for Ready, Partial) still apply their specific filters when clicked.
- `hasActiveFilters` is `false` for the new default state.

## Implementation constraints

- Preserve responsive behavior on mobile, tablet, and desktop.
- Reuse existing `AppSearchBarFilterGroup` / **All fields** pattern (`l10n.opdAllFieldsFilterLabel`) — do not introduce duplicate labels.
- Do not change backend API contracts; this is a frontend default/query-mapping fix.
- Keep **Ready** available as an explicit filter option; only change the **initial/default** filter.

## Acceptance criteria

- [ ] **Catalog and stock** opens reliably on first click without a page refresh.
- [ ] No invisible modal barrier — dialog is always visible and dismissible.
- [ ] Pharmacy worklist loads with **All fields** queue status on first visit.
- [ ] Empty state appears only when no orders match the current search/filter, not because **Ready** is pre-selected.
- [ ] Clear filters resets to **All fields** for queue status.
- [ ] Existing pharmacy and dialog tests pass; add/update tests for default query and dialog open behavior where practical.

## Verification

```bash
cd frontend
flutter test test/shared/components/app_dialog_test.dart test/shared/layout/app_dialog_insets_test.dart
```

**Manual checks (desktop web, `http://127.0.0.1:5201/pharmacy`):**

1. Navigate to Pharmacy without refreshing — click **Catalog and stock** → dialog appears and is usable.
2. Close dialog → page remains interactive.
3. Open **Queue filter** → **Queue status** shows **All fields** on first load.
4. Confirm orders from multiple statuses appear (if data exists).
5. Select **Ready**, then **Clear filters** → status returns to **All fields**, not **Ready**.
