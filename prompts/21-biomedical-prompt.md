# Standardize Biomedical Tables

## Objective

Refactor every `AppListTable` on the Biomedical workspace (`/biomedical`, `BiomedicalWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 default columns with extras in `columnChoices`, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden `columnChoices`)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared default columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, or unrelated screen chrome (tab toolbar primary/secondary actions, queue shortcuts, print flows) unless required for compilation.

## Current State (from audit)

### Screen shell

| Field | Value |
|-------|-------|
| Route | `/biomedical` (`AppRoutes.biomedical`, deep link `?panel=<value>`) |
| Page | `BiomedicalWorkspacePage` → `_BiomedicalWorkspaceContent` / `_BiomedicalWorkspaceContentState` |
| File | `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart` |
| Entity | `BiomedicalAsset` (`frontend/lib/features/biomedical/domain/entities/biomedical_entities.dart`) |
| Provider | `biomedicalWorkspaceControllerProvider` (`frontend/lib/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart`) — realtime via `listenForRealtimeRefresh` + `RealtimeEventGroups.biomedical` |
| Panels | `BiomedicalPanels`: `overview`, `registry`, `preventive`, `work-orders`, `compliance`, `support`, `analytics` |
| Detail dialog | `_openAssetDetailDialog` → `AppDialog` + `_BiomedicalDetailPanel` + `_DetailActions` |
| Action dialogs | `_openActionDialog` → `_BiomedicalActionDialog` with `_BiomedicalActionKind` enum |

### Table inventory (single widget, panel-switched columns)

There is **one** `AppListTable<BiomedicalAsset>` instance in `_BiomedicalWorkspaceContentState.build` (lines ~239–327). Columns change per `_currentPanel` via `_columnsForPanel(l10n)`. Column visibility controller is recreated on panel switch (`_switchPanel`, `_applyQueue`).

| Property | Current value |
|----------|---------------|
| Widget | `AppListTable<BiomedicalAsset>` in `_BiomedicalWorkspaceContentState` |
| `columnVisibilityStorageKey` | `'biomedical_$_currentPanel'` |
| `columnWidthStorageKey` | `'biomedical_cw_$_currentPanel'` |
| `columnVisibilityLabel` | `l10n.commonTableSettingsActionLabel` ✓ |
| `columnVisibilityTitle` | **missing** |
| `columnChoices` | **missing** — all columns declared in `columns` only |
| `displayMode` | default `AppListTableDisplayMode.adaptive` ✓ |
| `onRowSelected` | `_openAssetDetailDialog` ✓ |
| `mobileItemBuilder` | `_BiomedicalAssetListTile` — title/subtitle/status only; **no next action** |

### Per-panel column audit (declared `columns` count today)

| Panel | Column ids (in order) | Count | Gaps |
|-------|----------------------|-------|------|
| `registry` | `asset_tag`, `equipment`, `category`, `location`, `risk`, `status`, `owner` | **7** | Exceeds 5; no `next_action`; extras not in `columnChoices` |
| `overview` | `asset_tag`, `equipment`, `status`, `risk`, `next_action`, `owner` | **6** | Exceeds 5; `next_action` is plain `Text`; `owner` should be hidden choice |
| `preventive` | `asset_tag`, `equipment`, `status`, `next_due`, `owner` | **5** | Missing explicit `next_action`; `owner` should be hidden choice |
| `work-orders` | `asset_tag`, `equipment`, `status`, `risk`, `owner`, `next_action` | **6** | Exceeds 5; `next_action` is plain `Text` |
| `compliance` | `asset_tag`, `equipment`, `category`, `status`, `next_due`, `next_action` | **6** | Exceeds 5; `next_action` is plain `Text` |
| `support` | `asset_tag`, `equipment`, `category`, `location`, `status` | **5** | No `next_action`; `category`/`location` trade-off — move one to `columnChoices` |
| `analytics` | `asset_tag`, `equipment`, `location`, `status`, `next_action` | **5** | `next_action` is plain `Text`; mobile parity incomplete |

### Search chrome gaps

```dart
// biomedical_workspace_page.dart ~246-256
matcher: (_, _) => true,  // does NOT search column fields
advancedFilterButtonLabel: l10n.biomedicalFiltersLabel,  // "Filters" ✓
advancedFilterTitle: l10n.biomedicalFiltersLabel,           // "Filters" ✗ — must be "Advanced filters"
// columnVisibilityTitle not set                              // ✗ — must be "Table Settings"
```

Filters wiring is otherwise correct: `showAdvancedFilterButton: true`, `filterGroups` (status, priority, facility, date preset), `onFilterChanged` → `controller.applyFilters`. Refresh/export actions correctly live in tab toolbar, not search chrome.

### Status / next-action gaps

- `_statusColumn` uses `AppWorkspaceStatusBadge` via `_statusBadge` helper ✓ but lacks `alwaysVisible: true`.
- `_nextActionColumn` renders `Text(_nextActionLabel(...))` only — **not clickable**, no dialog/deep-link on press.
- `_nextActionLabel` (lines ~2280–2298) already has explicit per-resource labels (`biomedicalNextActionMaintain`, `biomedicalNextActionCalibrate`, `biomedicalNextActionReturnService`, `biomedicalNextActionReviewRecall`, `biomedicalNextActionWorkOrder`, `biomedicalNextActionReview`).
- Biomedical does **not** use encounter-based `WorkflowActionButton`; actions open `_BiomedicalActionDialog` via `_openActionDialog`. Build a module-local clickable next-action cell (see Target Architecture).

### Mobile gaps

`_BiomedicalAssetListTile` shows `displayTitle`, `displaySubtitle`, status badge only. Missing: priority/risk (when visible on panel), explicit next-action control, owner when relevant.

### Tests (current expectations to update)

`frontend/test/features/biomedical/presentation/biomedical_workspace_page_test.dart`:
- Registry tab expects `Risk` visible and `Owner` hidden (relies on AppListTable auto-capping at 5). After refactor, defaults become explicit 5-column plan below; update assertions.
- Filter dialog test taps `Filters` tooltip — keep working after title key change.
- Row tap opens `AppDialog` — must still pass.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `columnChoices`, `alwaysVisible`, default adaptive mode
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters/Settings chrome, `_matchesSearch`, `columnVisibilityController`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn`, `WorkflowActionButton` (pattern reference for clickable action column; biomedical uses `_openActionDialog` instead)
- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` — `_nextActionColumn` with `alwaysVisible: true` and clickable `WorkflowActionButton`
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `AppListTable<BiomedicalAsset>` | `registry` | `BiomedicalAsset` | asset_tag, equipment, location, status, next_action | `biomedical_registry` |
| same | `overview` | `BiomedicalAsset` | asset_tag, equipment, risk, status, next_action | `biomedical_overview` |
| same | `preventive` | `BiomedicalAsset` | asset_tag, equipment, next_due, status, next_action | `biomedical_preventive` |
| same | `work-orders` | `BiomedicalAsset` | asset_tag, equipment, risk, status, next_action | `biomedical_work-orders` |
| same | `compliance` | `BiomedicalAsset` | asset_tag, equipment, next_due, status, next_action | `biomedical_compliance` |
| same | `support` | `BiomedicalAsset` | asset_tag, equipment, location, status, next_action | `biomedical_support` |
| same | `analytics` | `BiomedicalAsset` | asset_tag, equipment, location, status, next_action | `biomedical_analytics` |

Use existing storage key pattern `'biomedical_$_currentPanel'` (already panel-specific). Keep `columnWidthStorageKey: 'biomedical_cw_$_currentPanel'`.

### Column plan (per panel)

Shared column builders (refactor existing private methods; do not duplicate):

| Column id | Label key | Source field | Builder notes |
|-----------|-----------|--------------|---------------|
| `asset_tag` | `biomedicalAssetTagColumnLabel` | `displayId` | `AppCopyableIdentifier` — keep |
| `equipment` | `biomedicalEquipmentColumnLabel` | `displayTitle` + `displaySubtitle` | Refactor `_AssetTitleCell` to `AppListItemText` (one field, two-line) |
| `category` | `biomedicalCategoryColumnLabel` | `categoryLabel` | `columnChoices` only |
| `location` | `biomedicalLocationColumnLabel` | `facilityLabel` | default or choice per panel |
| `risk` | `biomedicalRiskColumnLabel` | `priority` | `AppWorkspaceStatusBadge` via `_toneForPriority` |
| `status` | `biomedicalStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` via `_toneForStatus`; **`alwaysVisible: true`** |
| `owner` | `biomedicalOwnerColumnLabel` | `engineerLabel ?? facilityLabel` | `columnChoices` only |
| `next_due` | `biomedicalNextDueLabel` | `nextDueAt` | formatted date |
| `next_action` | `biomedicalNextActionColumnLabel` | computed | **`alwaysVisible: true`**; clickable `_BiomedicalNextActionCell` |

#### Default `columns` + `columnChoices` per panel

| Panel | `columns` (≤5, order matters) | `columnChoices` (hidden by default) |
|-------|--------------------------------|-------------------------------------|
| `registry` | asset_tag, equipment, location, status, next_action | category, risk, owner |
| `overview` | asset_tag, equipment, risk, status, next_action | owner |
| `preventive` | asset_tag, equipment, next_due, status, next_action | owner |
| `work-orders` | asset_tag, equipment, risk, status, next_action | owner |
| `compliance` | asset_tag, equipment, next_due, status, next_action | category |
| `support` | asset_tag, equipment, location, status, next_action | category |
| `analytics` | asset_tag, equipment, location, status, next_action | _(none — all five are defaults)_ |

Refactor `_columnsForPanel` into two methods:

```dart
List<AppListTableColumn<BiomedicalAsset>> _defaultColumnsForPanel(
  AppLocalizations l10n,
);

List<AppListTableColumn<BiomedicalAsset>> _columnChoicesForPanel(
  AppLocalizations l10n,
);
```

Pass both to `AppListTable`:

```dart
columns: _defaultColumnsForPanel(l10n),
columnChoices: _columnChoicesForPanel(l10n),
```

### Next-action mapping (explicit verbs — reuse existing l10n)

Implement helpers in `biomedical_workspace_page.dart`:

```dart
_BiomedicalActionKind? _nextActionKindForAsset(BiomedicalAsset asset);
// Returns null when the action is "review only" (open detail dialog).

String _nextActionLabel(AppLocalizations l10n, BiomedicalAsset asset); // already exists — keep
```

| Condition (`asset.resource` / `status`) | Label key | `_BiomedicalActionKind` | On press |
|----------------------------------------|-----------|-------------------------|----------|
| `maintenancePlans` | `biomedicalNextActionMaintain` | `maintenance` | `_openActionDialog(..., maintenance, asset: asset)` |
| `calibrationLogs` | `biomedicalNextActionCalibrate` | `calibration` | `_openActionDialog(..., calibration, asset: asset)` |
| `safetyTestLogs` | `biomedicalNextActionCalibrate` | `safety` | `_openActionDialog(..., safety, asset: asset)` |
| `downtimeLogs` or `status == 'DOWN'` | `biomedicalNextActionReturnService` | `closeDowntime` if `downtimeLogs`, else `returnToService` | matching dialog |
| `recallNotices` | `biomedicalNextActionReviewRecall` | `recall` | `_openActionDialog(..., recall, asset: asset)` |
| `workOrders` + `OPEN`/`PENDING` | `biomedicalNextActionWorkOrder` | `startWorkOrder` | `_openActionDialog(..., startWorkOrder, asset: asset)` |
| `workOrders` + `IN_PROGRESS` | `biomedicalNextActionReturnService` | `returnToService` | `_openActionDialog(..., returnToService, asset: asset)` |
| `workOrders` (other) | `biomedicalNextActionWorkOrder` | `workOrder` | `_openActionDialog(..., workOrder, asset: asset)` |
| default / registry | `biomedicalNextActionReview` | `null` | `_openAssetDetailDialog` |

Create `_BiomedicalNextActionCell` (private widget in same file):

- Accepts `BiomedicalAsset`, `canWrite`, `canPrint`, and callbacks `onOpenDetail`, `onOpenAction`.
- Renders a compact `TextButton` or `AppButton.tertiary` styled like `WorkflowActionButton` compact mode (see `frontend/lib/shared/workflow_actions/workflow_action_button.dart` `_CompactActionButton`).
- Label = `_nextActionLabel(l10n, asset)` — never generic "Action" / "Next step".
- Wrap with `GestureDetector` / `Listener` so press does **not** trigger row `onRowSelected`.
- Gate write actions with `AppAccessActionGate(requirement: _writeRequirement)`; read-only users still see label but button opens detail dialog only.
- Wire `_nextActionColumn` `cellBuilder` to `_BiomedicalNextActionCell`.

### Search chrome (all panels)

```dart
search: AppListTableSearch<BiomedicalAsset>(
  controller: _searchController,
  semanticLabel: l10n.biomedicalSearchLabel,
  hintText: l10n.biomedicalSearchHint,
  matcher: _matchesBiomedicalSearch,
  onSubmitted: controller.applySearch,
  onClear: () => controller.applySearch(''),
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.commonFiltersActionLabel,       // "Filters"
  advancedFilterTitle: l10n.commonAdvancedFiltersTitle,           // "Advanced filters"
  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
  advancedFilterResetLabel: l10n.opdClearFiltersAction,
  // ... existing filterGroups / onFilterChanged unchanged
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle,             // "Table Settings"
```

Implement `_matchesBiomedicalSearch(BiomedicalAsset item, String query)` searching **all** fields used by any column (defaults + choices):

```dart
bool _matchesBiomedicalSearch(BiomedicalAsset item, String query) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  final AppLocalizations l10n = /* obtain via a top-level helper or pass context-free formatters */;
  return <String?>[
    item.displayId,
    item.displayTitle,
    item.displaySubtitle,
    item.categoryLabel,
    item.facilityLabel,
    item.engineerLabel,
    item.status,
    item.priority,
    _labelForCode(item.status),
    _labelForCode(item.priority),
    _formatDateForSearch(item.nextDueAt),
    _nextActionLabel(/* needs l10n */, item),
    _labelForResource(/* needs l10n */, item.resource),
  ].whereType<String>().any((v) => v.toLowerCase().contains(normalized));
}
```

Keep server-side `onSubmitted: controller.applySearch` for paginated API search. The matcher satisfies `prompt.md` §1 for in-page filtering and Settings-hidden columns.

### Row interaction

- Keep `onRowSelected` → `_openAssetDetailDialog(context, asset, canWrite, canPrint)`.
- `_BiomedicalNextActionCell` must open the **same** destination as the corresponding button in `_DetailActions` (e.g. work-order row action → `_BiomedicalActionKind.workOrder` dialog, not module home).

### Mobile

Replace `_BiomedicalAssetListTile` with a panel-aware builder or pass panel into tile:

```dart
mobileItemBuilder: (context, item) => _BiomedicalAssetListTile(
  asset: item,
  panel: _currentPanel,
  canWrite: canWrite,
  onNextAction: (...) => ...,
  onOpenDetail: () => _openAssetDetailDialog(...),
),
```

Show: equipment (`AppListItemText`), panel-relevant field (location / risk / next_due), `AppWorkspaceStatusBadge` for status, trailing `_BiomedicalNextActionCell` (compact). Mirror desktop priority fields per panel table above.

## Implementation Steps

### 1. Add shared l10n keys (`frontend/lib/l10n/app_en.arb` only)

Add if missing (do not duplicate existing keys):

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run codegen (`flutter gen-l10n` or project equivalent) after editing arb.

Replace `l10n.biomedicalFiltersLabel` in **table search chrome only** with `commonFiltersActionLabel` / `commonAdvancedFiltersTitle`. Keep `biomedicalFiltersLabel` elsewhere if used outside table chrome.

### 2. Refactor column layout — `biomedical_workspace_page.dart`

1. Split `_columnsForPanel` into `_defaultColumnsForPanel` + `_columnChoicesForPanel` per tables above.
2. Add `next_action` to `registry`, `preventive`, `support` defaults.
3. Set `alwaysVisible: true` on `status` and `next_action` column definitions.
4. Refactor `_AssetTitleCell` → `AppListItemText(primary: displayTitle, secondary: displaySubtitle)`.
5. Pass `columnChoices:` to `AppListTable`.
6. Set `columnVisibilityTitle: l10n.commonTableSettingsTitle`.

### 3. Implement search matcher

1. Add `_matchesBiomedicalSearch` covering all column fields (including hidden choices).
2. Replace `matcher: (_, _) => true` with `_matchesBiomedicalSearch`.
3. Update filter modal title to `commonAdvancedFiltersTitle`.

### 4. Implement clickable next-action column

1. Add `_nextActionKindForAsset`.
2. Add `_BiomedicalNextActionCell` widget.
3. Update `_nextActionColumn` to use the cell widget.
4. Ensure action press stops row propagation.

### 5. Upgrade mobile list tile

1. Panel-aware `_BiomedicalAssetListTile` with status + next-action parity.
2. Explicit `displayMode: AppListTableDisplayMode.adaptive` (optional — already default; add for clarity if desired).

### 6. Update tests — `biomedical_workspace_page_test.dart`

1. Registry tab: expect default columns `Asset tag`, `Equipment`, `Location`, `Status`, `Next action` (or matching l10n). `Owner` and `Category` not in default header row.
2. Preventive tab: expect `Next due` and `Next action`.
3. Add test: tapping next-action button on a work-order asset opens `_BiomedicalActionDialog` (mock `workOrders` resource asset).
4. Add test: Settings tooltip opens column visibility (find `commonTableSettingsActionLabel` / `Table Settings` title).
5. Keep existing: tab switch URL, deep link, filter dialog, row detail dialog, search submit, mobile viewport.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/components.dart` | Session column visibility |
| `AppListTableColumnVisibilityMemory` | `package:hosspi_hms/shared/components/app_list_table_column_visibility_memory.dart` | Backing store (via controller) |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/components/components.dart` | Status + risk columns |
| `AppListItemText` | `package:hosspi_hms/shared/components/components.dart` | Equipment two-line cell |
| `AppCopyableIdentifier` | `package:hosspi_hms/shared/components/components.dart` | Asset tag column |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write next-actions |
| `showAppDialog` / `AppDialog` | `package:hosspi_hms/shared/layout/layout.dart` | Detail + action dialogs |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | **Do not use** — biomedical is not encounter-workflow; copy compact button **styling** only |

## Files to Create / Modify / Delete

| File | Action |
|------|--------|
| `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart` | **Modify** — columns, search, next-action cell, mobile tile |
| `frontend/lib/l10n/app_en.arb` | **Modify** — add shared filter/settings title keys if missing |
| `frontend/test/features/biomedical/presentation/biomedical_workspace_page_test.dart` | **Modify** — update/add table standardization tests |
| Generated l10n files | **Regenerate** after arb edit |

No new feature files required unless extracting `_BiomedicalNextActionCell` improves readability (optional; keep in same page file to minimize scope).

## l10n

- Edit `frontend/lib/l10n/app_en.arb` only (per locale rule).
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonTableSettingsTitle`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`.
- Reuse existing biomedical column/action keys: `biomedicalAssetTagColumnLabel`, `biomedicalNextActionMaintain`, etc.
- Do **not** rename panel tab keys (`biomedicalPanelRegistry`, etc.).

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/biomedical/
```

## Testing Requirements

- [ ] Each panel: search chrome shows only Filters + Settings (no export/refresh in search bar)
- [ ] Advanced filters modal title is **Advanced filters**; Settings modal title is **Table Settings**
- [ ] Column visibility persists per `biomedical_<panel>` storage key when toggling Settings
- [ ] Each panel: ≤5 default columns in `columns`; extras only in `columnChoices`
- [ ] Row number column is automatic (not declared)
- [ ] Status column second-from-right with `AppWorkspaceStatusBadge`; next-action rightmost with explicit verb label
- [ ] Next-action press opens contextual `_BiomedicalActionDialog` or detail dialog (never generic navigation)
- [ ] Row tap still opens `_openAssetDetailDialog`
- [ ] Mobile list shows same priority fields + status + next action
- [ ] `biomedicalWorkspaceControllerProvider` realtime refresh still updates rows after mutations
- [ ] `AppAccessActionGate` still gates write next-actions and toolbar actions
- [ ] Existing biomedical controller tests still pass: `test/features/biomedical/presentation/biomedical_workspace_controller_test.dart`

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the single panel-switched `AppListTable` on `/biomedical` (all seven panels)
- [ ] Domain logic, permissions, queues, deep links, and dialog payloads preserved
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/biomedical/` passes
