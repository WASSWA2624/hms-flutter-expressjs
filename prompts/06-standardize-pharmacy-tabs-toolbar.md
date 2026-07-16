# Standardize Pharmacy Screen (Tabs & Toolbar)

## Objective

Refactor the Pharmacy workspace (`/pharmacy`, `PharmacyWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

## Compliance Checklist (from prompt.md)

- [ ] No dedicated screen title/header
- [ ] Shared `AppTabStrip` at top with consistent vertical padding
- [ ] Toolbar immediately under tabs via `primaryAction` / `secondaryActions`
- [ ] All former header / more-menu actions relocated into the contextual toolbar
- [ ] Toolbar actions change with the active tab
- [ ] Every screen retains at least one toolbar button overall
- [ ] Tables expose only Filters and Settings inside the table area
- [ ] Consistent button labels (l10n) across tabs

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every
step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting
after implementation. Treat `prompt.md` as the normative layout contract.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.
**Preserve all Pharmacy domain logic** (desk section filters, order detail / dispense / attest /
return / cancel dialogs, catalog dialog + inventory deep links, permissions, counts, realtime
refresh, search/advanced filters, row selection). This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
  - Public widget: `PharmacyWorkspacePage` (`initialQuery: PharmacyWorkspaceQuery?`)
  - Content: `_PharmacyWorkspaceContent` / `_PharmacyWorkspaceContentState`
  - Worklist body: `_PharmacyQueuePanel` → `AppListTable<PharmacyOrder>`
  - Order detail / actions live in dialogs in the same file (`_openPharmacyDetailDialog`,
    dispense / attest / return / cancel dialogs) — **do not** move row/detail write actions into
    the screen tab toolbar
- Catalog dialog: `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart`
  - `openPharmacyCatalogDialog(context, ref, {initialTab})`
- Catalog panels (dialog-internal tables): `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`
- Controller: `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart`
  - Provider: `pharmacyWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyFilter(PharmacyOrderFilter)`, `applySearch`,
    `applyAdvancedFilters`, `applyInventoryFilter`, `selectOrder`, `prepareCatalogTab`, …
- Domain: `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`
  - Tabs: `PharmacyDeskSection` (`queue`, `inProgress`, `pendingPayment`, `completed`, `allOrders`)
  - Filters: `PharmacyOrderFilter` (`ready`, `partial`, `pendingPayment`, `completed`, `all`, …)
  - Query: `PharmacyWorkspaceQuery.fromUri` parses `section`, `encounterId`/`orderId`, `search`/`q`
- Route: `AppRoutes.pharmacy` path `/pharmacy` in `frontend/lib/app/router/app_routes.dart`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `PharmacyWorkspaceQuery.fromUri(state.uri)`
- Write gate (page-level constant today):
  ```dart
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
  );
  ```
- Tests: `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart`
  (tab strip, URL section sync, deep links, catalog overflow open, mobile list tiles)

### Current widget tree (chrome) — non-compliant

```
AsyncStateScaffold<PharmacyWorkspaceState>
  └── AppWorkspace(
        title: l10n.pharmacyTitle,          // title passed; showHeader defaults false
        leadingIcon: AppRouteIcons.pharmacy,
        toolbar: appWorkspaceToolbarWithLabels(  // ← renders ABOVE tabs (violation)
          summaryNotifications: Low stock / Almost out / Expiring soon,
          maxVisibleScreenActions: 1,
          overflowSections: [Catalog button, showsNotifications],  // ← “more” menu
          onRefresh: controller.refresh,
        ),
        body: Column(
          AppTabStrip(
            primaryAction: AppAccessActionGate → _primaryActionForSection(...),
            // secondaryActions: NOT passed
          ),
          SizedBox(height: theme.spacing.sm),
          _PharmacyQueuePanel → AppListTable,
        ),
      )
```

Even with `showHeader: false`, `AppWorkspace` still mounts `AppWorkspaceToolbar` when `toolbar`
is non-null. That puts Refresh / overflow / notifications **above** the tab strip — opposite of
`prompt.md` (tabs first, toolbar immediately beneath tabs).

### Confirmed tab inventory

| # | Tab label (l10n → EN) | Enum `PharmacyDeskSection` | Query `section=` written | Accepted aliases in `_sectionFromQuery` | Order filter applied |
|---|----------------------|----------------------------|--------------------------|-----------------------------------------|----------------------|
| 1 | `pharmacySummaryReadyLabel` → **Ready** | `queue` | `queue` | `queue`, `ready`, `dispense` | `PharmacyOrderFilter.ready` |
| 2 | `pharmacySummaryPartialLabel` → **Partial** | `inProgress` | `in-progress` | `in-progress`, `partial`, `in_progress` | `PharmacyOrderFilter.partial` |
| 3 | `pharmacyFilterPendingPayment` → **Pending payment** | `pendingPayment` | `pending-payment` | `pending-payment`, `payment`, `pending_payment` | `PharmacyOrderFilter.pendingPayment` |
| 4 | `pharmacySummaryCompletedLabel` → **Completed** | `completed` | `completed` | `completed`, `dispensed` | `PharmacyOrderFilter.completed` |
| 5 | `pharmacyFilterAll` → **All orders** | `allOrders` | `all` | `all`, `all-orders` | `PharmacyOrderFilter.all` |

Special deep link (keep): `?section=inventory` or `?section=stock` opens
`openPharmacyCatalogDialog(..., initialTab: PharmacyCatalogTab.inventory)` — not a desk tab.

Deep-link tab state **is already URL-backed** via `?section=…` and
`_updateUrlForSection` → `GoRouter.replace` + `PharmacyWorkspaceQuery.fromUri`. Keep and strengthen;
do not invent a second query key.

### Current tab toolbar (gaps)

`_primaryActionForSection` today:

| Section | Label | Actual behavior | Problem |
|---------|-------|-----------------|---------|
| `queue` / `inProgress` | `pharmacyDispenseAction` (“Dispense”) | `controller.applyFilter(PharmacyOrderFilter.ready)` | Fake CTA — re-applies Ready filter; real dispense is in order detail dialog |
| `pendingPayment` | `pharmacyQueueFilterLabel` (“Queue filter”) | `applyFilter(pendingPayment)` | Fake CTA — re-applies current section filter |
| `completed` / `allOrders` | `pharmacyCatalogPanelTitle` (“Catalog and stock”) | `openPharmacyCatalogDialog` | Sensible — keep as a real action |

Entire `primaryAction` is wrapped in `AppAccessActionGate(requirement: _writeRequirement)`, which
incorrectly write-gates **Catalog** open (read/browse). Overflow Catalog button is **not** gated.

`secondaryActions`: **empty** (not passed).

### Current `AppWorkspace` toolbar / more-menu (must relocate then remove)

From `appWorkspaceToolbarWithLabels` on the page:

1. **Refresh** — `onRefresh: controller.refresh` / `isRefreshing: state.isRefreshingOrders`
2. **Overflow “more” menu** (`overflowSections`):
   - Section header `pharmacyCatalogPanelTitle` → visible `AppButton.secondary` “Catalog and stock”
   - `AppToolbarOverflowSection(showsNotifications: true)` for summary notification overflow
3. **Summary notifications** (conditional on inventory summary counts):
   - Low stock → `_openCatalogForInventoryAlert(PharmacyInventoryFilter.lowStock)`
   - Almost out → `PharmacyInventoryFilter.almostOutOfStock`
   - Expiring soon → `PharmacyInventoryFilter.expiringSoon`

These must become **visible** `AppTabStrip` toolbar buttons (primary / secondary). Do **not** keep
an overflow / more menu for screen actions.

### Current table chrome (gaps)

In `_PharmacyQueuePanel`:

- Search: `AppListTableSearch` with `pharmacySearchHint` / `pharmacySearchLabel` — keep
- Filters: `showAdvancedFilterButton: true` with
  `advancedFilterButtonLabel: l10n.pharmacyQueueFilterLabel` → currently **“Queue filter”**
  (must become standardized **“Filters”**)
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently
  **“Table settings”** (must become **“Settings”**)
- Filter groups / date filters / paging already wired — preserve domain filter behavior
- No Refresh / Catalog in table trailing today (good once Settings/Filters labels are fixed)

Catalog dialog tables in `pharmacy_catalog_panel.dart` also use `pharmacyQueueFilterLabel` for the
Filters button — update those to the same standardized **Filters** label when changing the key.

### Concrete `prompt.md` gaps to close

1. **`AppWorkspace` toolbar sits above tabs** — dual chrome; tabs are not the top chrome.
2. **Overflow / more menu** still holds Catalog + notification overflow — forbidden for screen actions.
3. **Fake primary CTAs** on Ready / Partial / Pending payment (re-apply filters).
4. **Toolbar not meaningfully contextual** — broken primaries; secondaries empty; workspace actions global.
5. **Filters label** is “Queue filter”, not **Filters**.
6. **Settings label** is “Table settings”, not **Settings**.
7. Catalog incorrectly write-gated via tab `AppAccessActionGate` wrapper.
8. Tests still assert overflow Catalog open — must be rewritten for tab-toolbar Catalog.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` —
  canonical: `ResponsivePage` + `AppTabStrip` + table; **no** page `AppWorkspace` toolbar
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` —
  **copy this pattern** for per-tab `primaryAction` + `secondaryActions`
- `frontend/lib/shared/components/app_tab_strip.dart` —
  `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` / toolbar-only behavior (do **not**
  reintroduce page title header)
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; Pharmacy page must stop
  using `appWorkspaceToolbarWithLabels` for screen chrome
- `frontend/lib/shared/components/app_list_table.dart` — Filters + Settings wiring
- `frontend/lib/shared/components/app_search_bar.dart` — advanced Filters button
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — `showsToolbarActionLabels`, breakpoints
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage`, `PageMaxWidth`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Ready | `/pharmacy?section=queue` | Ordered / ready-to-dispense queue | **Catalog and stock** (`pharmacyCatalogPanelTitle`, icon `Icons.inventory_2_outlined`) → `openPharmacyCatalogDialog(context, ref)` — **not** write-gated | **Refresh** (`commonRefreshActionLabel`, icon `Icons.refresh`, `isLoading: state.isRefreshingOrders` → `controller.refresh()`); then conditional inventory alerts (see below) |
| Partial | `/pharmacy?section=in-progress` | Partially dispensed queue | **Catalog and stock** (same as Ready) | **Refresh** + conditional inventory alerts |
| Pending payment | `/pharmacy?section=pending-payment` | Orders awaiting payment | **Billing** (`navigationBillingLabel` / short label, icon `Icons.payments_outlined`) → `context.go(AppRoutes.billing.location())` — navigation only | **Catalog and stock** (`AppTabToolbarAction`); **Refresh** |
| Completed | `/pharmacy?section=completed` | Dispensed orders | **Catalog and stock** | **Refresh** only (omit inventory alert secondaries on this tab) |
| All orders | `/pharmacy?section=all` | Unscoped worklist | **Catalog and stock** | **Refresh** + conditional inventory alerts |

**Conditional inventory alert secondaries** (Ready / Partial / All orders only) — each as its own
visible `AppTabToolbarAction` (never a more-menu). Include only when count &gt; 0:

| When | Label (l10n) | Handler |
|------|--------------|---------|
| `criticalStockRows > 0` | `pharmacySummaryLowStockLabel` (“Low stock”), icon `Icons.warning_amber_outlined` | `_openCatalogForInventoryAlert(PharmacyInventoryFilter.lowStock)` |
| `almostOutOfStockRows > 0` | `pharmacySummaryAlmostOutLabel` (“Almost out”), icon `Icons.inventory_outlined` | `_openCatalogForInventoryAlert(PharmacyInventoryFilter.almostOutOfStock)` |
| `expiringSoonRows > 0` | `pharmacySummaryExpiringSoonLabel` (“Expiring soon”), icon `Icons.event_busy_outlined` | `_openCatalogForInventoryAlert(PharmacyInventoryFilter.expiringSoon)` |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction`
  for left-cluster secondaries (matches `AppTabStrip` contract / HR pattern).
- **Remove** fake “Dispense” and “Queue filter” tab primaries. Real dispense / attest / return /
  cancel stay inside order detail dialogs with existing write gates.
- **Do not** wrap Catalog or Billing in `AppAccessActionGate(pharmacyWrite)`. Keep `_writeRequirement`
  for detail/dialog write actions only.
- Guarantee ≥1 toolbar button on every tab (Catalog and/or Billing + Refresh cover this).
- Prefer consistent Catalog label `pharmacyCatalogPanelTitle` everywhere (do not invent synonyms).

### Routing

- Keep `/pharmacy` registration in `app_router.dart` unchanged.
- Keep query key **`section`** (already written by `_updateUrlForSection` / parsed by
  `PharmacyWorkspaceQuery.fromUri`).
- Canonical write values must remain: `queue` | `in-progress` | `pending-payment` | `completed` | `all`
- Keep alias parsing in `_sectionFromQuery` (including `ready` / `partial` / `inventory` / `stock`).
- On tab tap: `setState` + `_updateUrlForSection(section)` + `controller.applyFilter(_filterForSection(section))` (already present).
- Preserve `_handleSectionDeepLink` inventory/stock → catalog dialog behavior.
- Preserve encounter/order/search deep-link selection via `_applyRouteQuery`.

### Page Layout

Precise widget tree:

1. Keep outer `AsyncStateScaffold<PharmacyWorkspaceState>` (loading only — not a screen title bar).
2. Replace page-level `AppWorkspace(title:, toolbar:, …)` with Reception-style:
   ```dart
   ResponsivePage(
     maxWidth: PageMaxWidth.dataHeavy,
     child: SizedBox(
       width: double.infinity,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: <Widget>[
           AppTabStrip(
             tabs: …,
             selectedId: _section.name,
             onTabTapped: …,
             primaryAction: _primaryActionForSection(...),   // contextual, no write-gate wrap
             secondaryActions: _secondaryActionsForSection(...),
           ),
           SizedBox(height: theme.spacing.sm),
           _PharmacyQueuePanel(...),
         ],
       ),
     ),
   )
   ```
3. Equivalent acceptable alternative: `AppWorkspace(showHeader: false, toolbar: null, …)` **only if**
   no title header and no page `AppWorkspaceToolbar` render — Reception’s `ResponsivePage` path is preferred.
4. Body: `_PharmacyQueuePanel` → `AppListTable` with **only** Filters + Settings in the table chrome
   (plus search field — allowed).
5. No FAB / floating header actions / overflow more-menu for screen actions.
6. Keep using `AppWorkspaceDetailPanel` / `AppWorkspaceStatusBadge` / etc. **inside dialogs** — those
   are not screen chrome.

### Data & State Management

Reuse (do not replace):

- `pharmacyWorkspaceControllerProvider` /
  `PharmacyWorkspaceController` —
  `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart`
- `PharmacyWorkspaceState`, `PharmacyDeskSection`, `PharmacyOrderFilter`, `PharmacyWorkspaceQuery`,
  `PharmacyInventoryFilter`, `PharmacyCatalogTab` —
  `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`
- `openPharmacyCatalogDialog` —
  `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart`
- Existing helpers: `_openCatalogForInventoryAlert`, `_filterForSection`, `_sectionToQueryValue`,
  `_sectionFromQuery`, `_updateUrlForSection`, `_sectionCount` / tone / icon / label helpers
- Shell badge counts via `shell_badge_counts.dart` — unchanged

## Implementation Steps

1. **Normalize Filters + Settings labels (l10n)** — File: `frontend/lib/l10n/app_en.arb`
   (+ regenerate / update generated localizations if the project expects it)
   - Change `pharmacyQueueFilterLabel` English value from `"Queue filter"` to `"Filters"`
     (already wired as `advancedFilterButtonLabel` on the worklist and catalog panel tables).
   - Change shared `commonTableSettingsActionLabel` English value from `"Table settings"` to
     `"Settings"` (affects all workspaces intentionally — required standardization).
   - If another screen already flipped `commonTableSettingsActionLabel` to `"Settings"`, skip that
     arb edit and verify only.
   - Keep dialog filter **titles** (`pharmacyFiltersSemanticLabel` = “Pharmacy queue filters”) as-is
     unless they are used as the button label (they are not).

2. **Remove page `AppWorkspace` toolbar chrome** — File:
   `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
   - Delete `toolbar: appWorkspaceToolbarWithLabels(...)` (summaryNotifications, overflowSections,
     onRefresh, maxVisibleScreenActions).
   - Switch build method to `ResponsivePage` + `Column` + `AppTabStrip` + `_PharmacyQueuePanel`
     (mirror Reception).
   - Stop passing `title:` / `leadingIcon:` as screen header chrome.
   - Keep `_openCatalogForInventoryAlert` helper; call it from new secondary toolbar actions.

3. **Build contextual `primaryAction` / `secondaryActions`** — same page file
   - Replace `_primaryActionForSection` with the Target Architecture table above.
   - Add `_secondaryActionsForSection(AppLocalizations l10n, PharmacyWorkspaceState state,
     PharmacyWorkspaceController controller)` returning `List<Widget>` of `AppTabToolbarAction`.
   - Pass both into `AppTabStrip`.
   - Remove the `AppAccessActionGate` wrapper around the whole `primaryAction` for Catalog/Billing.
   - Ensure Refresh uses `AppTabToolbarAction` with `isLoading: state.isRefreshingOrders` and shows
     failures via existing `_showFailureIfNeeded` after `controller.refresh()`.

4. **Keep table chrome limited to Filters + Settings** — `_PharmacyQueuePanel`
   - Keep `showAdvancedFilterButton: true` and filter groups / date filters / apply handlers.
   - After step 1, `advancedFilterButtonLabel: l10n.pharmacyQueueFilterLabel` must render **Filters**.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → **Settings**.
   - Do **not** add Refresh / Catalog / Billing into `AppListTableSearch.trailingActions`.

5. **Update catalog panel Filters label consistency** — File:
   `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`
   - After arb change, `pharmacyQueueFilterLabel` already used as Filters button — verify it shows
     **Filters**. No new chrome inventing required.

6. **Update tests** — File:
   `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart`
   - Keep tab strip / count / URL / deep-link / pending-payment column / mobile list tests.
   - Replace “opens catalog from overflow action” with open from **visible tab-toolbar** Catalog
     button (`AppTabToolbarPrimary` / text “Catalog and stock”).
   - Ready / Partial tabs: stop asserting fake “Dispense” as the primary chrome CTA; assert Catalog
     (and/or Refresh) instead.
   - Pending payment: assert **Billing** primary appears after tab switch.
   - Completed / All orders: assert Catalog primary still present.
   - Assert **no** `AppWorkspaceToolbar` / overflow more control is required to reach Catalog.
   - Escape-close catalog test: if `find.text('Pharmacy')` depended on `AppWorkspace` title chrome,
     assert shell / route / worklist content instead (e.g. Ready tab or an order row still visible).
   - Optionally add: deep link `?section=pending-payment` selects Pending payment tab; toolbar
     primary is Billing.

7. **Format + analyze + test** (commands in Verification Steps).

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Filters + Settings only in table chrome |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page shell without title header |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Detail/dialog write actions only — not Catalog/Billing chrome |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/components.dart` | Loading / error shell |
| `openPharmacyCatalogDialog` | `package:hosspi_hms/features/pharmacy/presentation/pharmacy_catalog_dialog.dart` | Catalog primary / inventory alerts |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | `/pharmacy` location + Billing handoff |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive toolbar label visibility |

**Forbidden:** new custom tab bars; new screen header widgets; new table action buttons besides
Filters/Settings; new overflow/more menus for screen actions; reintroducing
`appWorkspaceToolbarWithLabels` on this page; FABs for Catalog/Refresh.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` — remove `AppWorkspace` toolbar chrome; `ResponsivePage` + contextual `AppTabStrip` actions |
| Modify | `frontend/lib/l10n/app_en.arb` — `pharmacyQueueFilterLabel` → `"Filters"`; `commonTableSettingsActionLabel` → `"Settings"` (if not already) |
| Modify | Generated l10n outputs if required by project workflow (`app_localizations*.dart`) |
| Modify | `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart` — toolbar / Catalog / Billing / no-overflow assertions |
| Verify only | `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` — Filters label via shared key |
| Do not modify (unless blocking bug) | `app_tab_strip.dart`, `app_list_table.dart`, Reception / HR reference pages, router registration |

## Cleanup: Remove Stale Code

- [ ] Remove `appWorkspaceToolbarWithLabels` / `overflowSections` / `summaryNotifications` from page build
- [ ] Remove fake Dispense / Queue-filter `_primaryActionForSection` branches that only call `applyFilter`
- [ ] Remove page-level `AppAccessActionGate` wrapping Catalog/Billing tab toolbar
- [ ] Remove unused imports (`AppToolbarOverflowSection`, toolbar helpers) if no longer referenced on the page
- [ ] Do **not** delete dialog detail panels, catalog dialog, inventory helpers, or domain controllers
- [ ] Confirm no orphaned private widgets left only for the old header overflow

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome refactor only.

## Responsive Design Requirements

- **Desktop (≥1024px / especially ≥1200 `xl` where `showsToolbarActionLabels` is true):** full tab
  labels; labeled Catalog/Billing primary; labeled Refresh + conditional inventory secondaries;
  full `AppListTable` with Filters + Settings labels visible.
- **Tablet (600–1023px / `md`–`lg`):** horizontal-scroll tabs; toolbar under tabs (icon-first when
  `showsToolbarActionLabels` is false); table may compress columns — Settings/Filters remain available.
- **Mobile (&lt;600px / `xs`–`sm`):** keep existing `mobileItemBuilder` (`_PharmacyOrderListTile`);
  tabs scroll horizontally; toolbar still under tabs (not a FAB); no header title bar.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/pharmacy/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL `section` query and toolbar actions
- [ ] Deep link opens correct tab (`queue` / `in-progress` / `pending-payment` / `completed` / `all`)
- [ ] `?section=inventory` / `stock` still opens catalog inventory dialog
- [ ] Per-tab toolbar shows only that tab’s actions (Billing primary only on Pending payment; inventory
      alert secondaries omitted on Completed / Pending payment)
- [ ] Table chrome has only Filters and Settings (plus search)
- [ ] No screen title/header chrome; no `AppWorkspaceToolbar` above tabs
- [ ] At least one toolbar button exists on every tab
- [ ] Catalog opens from visible tab toolbar (not overflow)
- [ ] Detail dialog write actions still permission-gated
- [ ] Responsive / mobile list tile layout still works

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu / overflow for screen actions
- [ ] Domain logic preserved (filters, counts, catalog, inventory alerts, deep links, detail dialogs)
- [ ] Filters label is **"Filters"**; Settings label is **"Settings"**
- [ ] Analyze clean; tests pass; stale header/overflow chrome removed
