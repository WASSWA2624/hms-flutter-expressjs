# Standardize Radiology Tables

## Objective

Refactor every `AppListTable` on the Radiology workspace (`/radiology`, `RadiologyWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only** on `RadiologyWorkspacePage` and its directly hosted dialog (`_RadiologyConfigurationsDialog`). Do not rewrite domain APIs, permissions, unrelated tab-toolbar actions (Request imaging, Refresh, Orders/Patients view toggle, Configurations), or detail-dialog mutation logic unless required for compilation.

**Route:** `/radiology` — deep-link query parameters: `?section=<value>` (aliases: `panel`, `tab`), plus `encounterId`, `orderId`, `search` / `q`.

---

## Current State (from audit)

### Screen inventory

| Field | Value |
|-------|-------|
| Route | `/radiology` |
| Page widget | `RadiologyWorkspacePage` |
| Content state | `_RadiologyWorkspaceContentState` |
| Primary file | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` |
| Part files | `radiology_workspace_page.detail_cells.dart`, `radiology_workspace_page.configurations.dart`, `radiology_workspace_page.print.dart` |
| Entity (worklist) | `RadiologyOrder` |
| Provider | `radiologyWorkspaceControllerProvider` (`RadiologyWorkspaceController`) |
| Detail dialog | `_openRadiologyDetailDialog` → `AppDialog` + `_RadiologyOrderDetail` / `_RadiologyDetailBody` |
| Column controller | `AppListTableColumnVisibilityController<RadiologyOrder>` in `_RadiologyWorkspaceContentState` (`_tableColumnController`) |

There are **two** `AppListTable` instances in the Radiology feature UI:

1. **`_RadiologyOrderBoard`** — main workspace worklist (all tabs share one table instance).
2. **`AppListTable<RadiologyCatalogTest>`** inside **`_RadiologyConfigurationsDialog`** (`radiology_workspace_page.configurations.dart`).

> Note: The generator inventory referenced `_RadiologyWorklistPanel`; the actual widget class is **`_RadiologyOrderBoard`**.

---

### Table 1 — `_RadiologyOrderBoard` (workflow worklist)

| Attribute | Value |
|-----------|-------|
| Widget | `_RadiologyOrderBoard` |
| File | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` (~line 515) |
| Entity | `RadiologyOrder` |
| Tabs | Single table; `RadiologyDeskSection` tab strip filters `query.stage` via controller |
| View toggle | `RadiologyWorkbenchView.patients` / `.orders` via tab-toolbar **Orders view** / **Patients view** |
| Storage keys | **Missing** `columnVisibilityStorageKey` and `columnWidthStorageKey` |
| Row detail | `onRowSelected` → `_openRadiologyDetailDialog` ✓ |
| `displayMode` | Not set explicitly (defaults to `AppListTableDisplayMode.adaptive`) ✓ |
| `mobileItemBuilder` | `_RadiologyOrderListTile` — partial parity (see gaps) |

#### Tab / section matrix (`RadiologyDeskSection`)

| Section | URL `section` | `applyStage` value | l10n tab label key | Count field |
|---------|---------------|-------------------|-------------------|-------------|
| `worklist` | `worklist` | `ALL` | `radiologyWorklistSummaryLabel` ("Worklist") | `state.workloadCount` |
| `reporting` | `reporting` | `REPORTING` | `radiologyReportingSummaryLabel` ("Reporting") | `state.reportingCount` |
| `released` | `released` | `COMPLETED` | `radiologyReleasedSummaryLabel` ("Released") | `state.releasedCount` |
| `allOrders` | `all` | `ALL` | `radiologyAllOrdersSummaryLabel` ("All orders") | `state.summary.totalForView(view)` |

Tabs change **which rows** are loaded (stage filter); column definitions switch only on **Patients vs Orders view**, not per tab.

#### Patients view — `_patientViewWorklistColumns` (5 columns — at limit but wrong workflow layout)

| # | id | Label (l10n) | field / builder | Gap |
|---|-----|--------------|-----------------|-----|
| 1 | `patient` | `radiologyPatientColumnLabel` | `patientDisplayName` — plain `Text` via `_radiologyWorklistTextCell` | Should use `AppListItemText` with `patientId` subtitle |
| 2 | `study` | `radiologyStudyColumnLabel` | `testsSummary` / `testDisplayName` | OK |
| 3 | `priority` | `radiologyPriorityColumnLabel` | `_radiologyPriorityDisplayLabel` | OK as triage field |
| 4 | `next_action` | `radiologyNextActionColumnLabel` | **Plain text** from `_nextActionLabel` | Must be interactive explicit-action control |
| 5 | `status` | `radiologyStatusColumnLabel` | `AppWorkspaceStatusBadge` via `_orderStatus` | **Wrong position** — must be column 4 (second from right) |

#### Orders view — `_orderViewWorklistColumns` (**6 columns — violates ≤5**)

| # | id | Label (l10n) | field / builder | Gap |
|---|-----|--------------|-----------------|-----|
| 1 | `orders` | `radiologyOrderColumnLabel` | `effectiveDisplayId` / active order count | OK |
| 2 | `patient` | `radiologyPatientColumnLabel` | `patientDisplayName` text | Should use `AppListItemText` |
| 3 | `study` | `radiologyStudyColumnLabel` | study summary | OK |
| 4 | `priority` | `radiologyPriorityColumnLabel` | priority label | OK |
| 5 | `next_action` | `radiologyNextActionColumnLabel` | plain `_nextActionLabel` text | Must be interactive |
| 6 | `status` | `radiologyStatusColumnLabel` | `AppWorkspaceStatusBadge` | **Exceeds budget**; wrong position |

#### Hidden `columnChoices` — `_optionalRadiologyWorklistColumns` (8 columns ✓)

| id | label key | field |
|----|-----------|-------|
| `patient_id` | `radiologyPatientIdLabel` | `patientId` |
| `orders` | `radiologyOrdersColumnLabel` | order identifier (patients view variant) |
| `modality` | `radiologyModalityLabel` | `modality` |
| `body_region` | `radiologyBodyRegionLabel` | `bodyRegion` |
| `laterality` | `radiologyLateralityLabel` | `laterality` |
| `encounter` | `radiologyEncounterColumnLabel` | `encounterId` |
| `billing` | `radiologyPaymentAuthColumnLabel` | billing gate label |
| `ordered_at` | `radiologyOrderedAtLabel` | `orderedAt` |

#### Search chrome gaps (`_RadiologyOrderBoard`)

| Issue | Current | Required |
|-------|---------|----------|
| Search matcher | `matcher: (_, _) => true` — server-only | Client matcher covering all column + `columnChoices` fields (keep server `applySearch` debounce) |
| Filters button label | `radiologyFiltersLabel` ("Filters") ✓ | Keep or migrate to `commonFiltersActionLabel` |
| Advanced filters modal title | `advancedFilterTitle: l10n.radiologyFiltersLabel` ("Filters") | **`commonAdvancedFiltersTitle`** ("Advanced filters") |
| Settings button label | `commonTableSettingsActionLabel` ("Settings") ✓ | unchanged |
| Settings modal title | `columnVisibilityTitle: l10n.radiologyTableColumnsTitle` ("Radiology columns") | **`commonTableSettingsTitle`** ("Table Settings") |
| Extra search chrome actions | None ✓ | Refresh/view toggle correctly in tab toolbar |
| Session column visibility key | **Missing** | Add per-section + per-view storage keys |
| Column width persistence | **Missing** | Add `columnWidthStorageKey` |

Current filter groups (preserve wiring): `stage`, `status`, `modality`, `priority`, `billing_gate` + order-date filter. Filter key constants in `radiology_workspace_page.detail_cells.dart`: `_radiologyStageFilterKey`, `_radiologyStatusFilterKey`, `_radiologyModalityFilterKey`, `_radiologyPriorityFilterKey`, `_radiologyBillingGateFilterKey`.

#### Row interaction (preserve core flow)

```dart
onRowSelected: (RadiologyOrder order) {
  unawaited(
    _openRadiologyDetailDialog(
      context, ref, state, order,
      canWork: canWork,
      canRequest: canRequest,
    ),
  );
},
```

`_openRadiologyDetailDialog` calls `controller.selectOrder(order)` then shows `AppDialog` with `_RadiologyOrderDetail`. Detail body (`_RadiologyDetailBody`) exposes workflow actions: assign, start imaging, perform study, release report, doctor review — aligned with `_nextActionLabel`.

#### Mobile gaps (`_RadiologyOrderListTile`)

Shows patient name, status badge, study|priority line, next-action **text**. Missing:

- Interactive next-action control (button) matching desktop column
- Orders-view fields when in orders view (order id)
- Optional parity for priority when hidden on narrow layouts

#### Workflow next-action labels (`_nextActionLabel` in `radiology_workspace_page.detail_cells.dart`)

| Condition | l10n key | English label |
|-----------|----------|---------------|
| `normalizedStatus == 'CANCELLED'` | `radiologyStatusCancelled` | Cancelled |
| `!hasBillingGate` | `radiologyNextActionConfirmBilling` | Confirm billing |
| `normalizedStatus == 'ORDERED'` | `radiologyNextActionStartImaging` | Start imaging |
| `IN_PROCESS` && `studyCount == 0` | `radiologyNextActionPerformStudy` | Perform study |
| `hasDraftResult` | `radiologyNextActionReleaseReport` | Release report |
| `hasFinalResult` or `COMPLETED` | `radiologyNextActionDoctorReview` | Doctor review |
| default | `radiologyNextActionReportPending` | Report pending |

Status column uses `_orderStatus` → `AppWorkspaceStatusBadge` with `_orderStatusLabel` for `ORDERED`, `IN_PROCESS`, `COMPLETED`, `CANCELLED`.

#### Realtime (preserve)

`RadiologyWorkspaceController` uses `listenForRealtimeRefresh` with `RealtimeEventGroups.radiology`, `WorkspaceRefreshProfile.radiology`, and adaptive polling. Table reads `state.orders` from `radiologyWorkspaceControllerProvider` — do not mutate table widgets directly.

---

### Table 2 — `_RadiologyConfigurationsDialog` catalog table

| Attribute | Value |
|-----------|-------|
| Widget | `AppListTable<RadiologyCatalogTest>` in `_RadiologyConfigurationsDialogState.build` |
| File | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart` (~line 327) |
| Entity | `RadiologyCatalogTest` (non-workflow facility catalog) |
| Row detail | **Missing** `onRowSelected` |
| Storage keys | **Missing** `columnVisibilityStorageKey` / `columnWidthStorageKey` |
| Column controller | `AppListTableColumnVisibilityController<RadiologyCatalogTest>` (`_testColumnController`) |

**Default columns today (6 — violates ≤5):**

| # | id | Label | Builder | Gap |
|---|-----|-------|---------|-----|
| 1 | *(selection)* | — | `_offeringSelectionColumn` — checkbox column | Not a semantic data field; move to mobile/row chrome |
| 2 | `name` | `radiologyTestNameLabel` | `AppListItemRow` with subtitle `effectiveId` + `code` | Subtitle merges **two** fields (id + code) — use name + code only, or name alone |
| 3 | `code` | `radiologyTestCodeLabel` | `code` | OK |
| 4 | `modality` | `radiologyModalityLabel` | `_ModalityLabel` | OK |
| 5 | `price` | `clinicalRequestUnitPriceLabel` | formatted unit price | OK |
| 6 | `actions` | `radiologyActionColumnLabel` | edit/delete `AppButton`s via `_testActionsColumn` | Action column — demote to `columnChoices` or row tap + mobile trailing |

**Hidden `columnChoices`:** `body_region`, `laterality`.

**Search chrome gaps:** same non-standard modal titles as worklist (`radiologyFiltersLabel` for both button and modal title; `radiologyTableColumnsTitle` for Settings). Matcher uses `item.matchesSearch(query)` ✓.

**Scope note:** Catalog table has no workflow status. Per `prompt.md` §3 (no workflow): up to five priority data columns; extras in `columnChoices`.

---

## Reference Implementation

Copy patterns from these files (read before editing):

| File | Pattern to copy |
|------|-----------------|
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable`, `AppListTableSearch`, `columnChoices`, `columnVisibilityStorageKey` |
| `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` | `_MortuaryWorklist` — Filters + Settings search chrome, `filterGroups`, `columnVisibilityController` |
| `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` | `emergencyNextActionColumn()` + `WorkflowActionButton` with `compact: true` |
| `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` | `_optionalWorklistColumns`, `_openLabDetailDialog` + `WorkflowActionButton` fallback pattern |
| `frontend/lib/shared/workflow_actions/workflow_action_button.dart` | `WorkflowActionButton` |
| `frontend/lib/shared/workflow_actions/workflow_action_registry.dart` | `_radiologyActions` (`PERFORM_IMAGING` → radiology route with `encounterId`/`orderId`) |
| `prompt.md` | Normative contract |

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` |
|--------------|-------------|--------|----------------------------------|------------------------------|
| `_RadiologyOrderBoard` | All 4 `RadiologyDeskSection` tabs × **Patients view** | `RadiologyOrder` | `patient`, `study`, `priority`, `status`, `next_action` | `radiology_${section.name}_patients` |
| `_RadiologyOrderBoard` | All 4 tabs × **Orders view** | `RadiologyOrder` | `orders`, `patient`, `study`, `status`, `next_action` | `radiology_${section.name}_orders` |
| `_RadiologyConfigurationsDialog` catalog | Configurations dialog | `RadiologyCatalogTest` | `name`, `code`, `modality`, `price`, `body_region` | `radiology_catalog_tests` |

Also set `columnWidthStorageKey`: `radiology_cw_${section.name}_${view.name}` (worklist) and `radiology_catalog_cw_tests` (catalog).

Pass section + view into `_RadiologyOrderBoard` (or read from `state.query.view` and parent `_section`) to compute storage keys dynamically.

### Column plan — Worklist, **Patients view** (all tabs)

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `patient` | `radiologyPatientColumnLabel` | `patientDisplayName` + `patientId` | `AppListItemText` primary/subtitle (`frontend/lib/shared/components/app_list_item_text.dart`) |
| 2 | `study` | `radiologyStudyColumnLabel` | `testsSummary` / `testDisplayName` | `_radiologyStudyLabel` |
| 3 | `priority` | `radiologyPriorityColumnLabel` | `_radiologyPriorityDisplayLabel(l10n, priority)` | triage field |
| 4 | `status` | `radiologyStatusColumnLabel` | `AppWorkspaceStatusBadge(status: _orderStatus(context, item))` | **second from right** |
| 5 | `next_action` | `radiologyNextActionColumnLabel` | `_RadiologyNextActionCell` | `alwaysVisible: true`; explicit verb label per row |

**Demote `priority` to `columnChoices`** if a tab needs a different third field — default keeps priority visible for all tabs.

### Column plan — Worklist, **Orders view**

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `orders` | `radiologyOrderColumnLabel` | `effectiveDisplayId` / active count | `_radiologyOrderIdentifierColumn` logic |
| 2 | `patient` | `radiologyPatientColumnLabel` | name + `patientId` | `AppListItemText` |
| 3 | `study` | `radiologyStudyColumnLabel` | study summary | |
| 4 | `status` | `radiologyStatusColumnLabel` | `_orderStatus` badge | |
| 5 | `next_action` | `radiologyNextActionColumnLabel` | `_RadiologyNextActionCell` | interactive |

**Move to `columnChoices`:** `priority`, `patient_id`, `orders` (patients-view variant), `modality`, `body_region`, `laterality`, `encounter`, `billing`, `ordered_at`.

### Column plan — Catalog table (non-workflow)

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `name` | `radiologyTestNameLabel` | `name` | single field; optional subtitle = `code` only |
| 2 | `code` | `radiologyTestCodeLabel` | `code` | |
| 3 | `modality` | `radiologyModalityLabel` | `modality` | `_ModalityLabel` |
| 4 | `price` | `clinicalRequestUnitPriceLabel` | `unitPrice` | |
| 5 | `body_region` | `radiologyBodyRegionLabel` | `bodyRegion` | promote from `columnChoices` |

**Remove from default columns:** `_offeringSelectionColumn`, `_testActionsColumn`. Keep bulk-selection checkbox in dialog toolbar or `mobileItemBuilder` only. Move `laterality` to `columnChoices`. Row tap opens edit offering dialog (`_openEditOfferingDialog`). Keep edit/delete in `mobileItemBuilder` trailing (`_testActionButtons`).

### Search chrome (per table)

**Worklist `_RadiologyOrderBoard`:**

```dart
search: AppListTableSearch<RadiologyOrder>(
  controller: searchController,
  semanticLabel: l10n.radiologySearchLabel,
  hintText: l10n.radiologySearchHint,
  matcher: _radiologyWorklistSearchMatcher, // implement — see below
  onChanged: onSearchChanged,
  onSubmitted: onSearchSubmitted,
  onClear: () => onSearchSubmitted(''),
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.commonFiltersActionLabel, // or keep radiologyFiltersLabel
  advancedFilterTitle: l10n.commonAdvancedFiltersTitle, // "Advanced filters"
  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
  advancedFilterResetLabel: l10n.radiologyClearFiltersAction,
  dateFilterLabel: l10n.radiologyOrderDateFilterLabel,
  dateFromLabel: l10n.radiologyOrderDateFilterLabel,
  dateToLabel: l10n.opdDateToLabel,
  datePickerButtonLabel: l10n.radiologyPickOrderDateAction,
  invalidDateMessage: l10n.appDateInvalidMessage,
  firstDate: DateTime(2020),
  lastDate: DateTime(2100),
  currentDate: DateTime.now(),
  allFieldsLabel: l10n.opdAllFieldsFilterLabel,
  filterGroups: /* preserve existing stage/status/modality/priority/billing groups */,
  filterValue: _radiologyFilterValue(state.query),
  hasActiveFilters: _hasRadiologyFilters(state.query),
  onFilterChanged: /* preserve existing controller.apply* calls */,
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle, // "Table Settings"
columnVisibilityStorageKey: 'radiology_${section.name}_${state.query.view.name}',
columnWidthStorageKey: 'radiology_cw_${section.name}_${state.query.view.name}',
```

Implement `_radiologyWorklistSearchMatcher(BuildContext context, RadiologyOrder item, String query)` in `radiology_workspace_page.detail_cells.dart` covering:

- `patientDisplayName`, `patientId`, `effectiveDisplayId`, `displayId`, `id`
- `testsSummary`, `testDisplayName`, `modality`
- Formatted `_orderStatusLabel`, `_radiologyPriorityDisplayLabel`, `_billingGateLabel`, `_nextActionLabel`
- `bodyRegion`, `laterality`, `encounterId`, formatted `orderedAt`
- Active order count label for patient groups

Keep server-side `applySearch` debounce in `_RadiologyWorkspaceContentState` — matcher provides instant feedback on the current page.

**Catalog table:** standardize titles; keep `item.matchesSearch(query)`; add storage keys.

### Row interaction

**Worklist — next-action cell**

Create `_RadiologyNextActionCell` (in `radiology_workspace_page.detail_cells.dart` or a small widget file under `presentation/widgets/`):

```dart
// Pattern: explicit label + opens same destination as detail dialog actions
class _RadiologyNextActionCell extends ConsumerWidget {
  // ...
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label = _nextActionLabel(context, order);
    final String? encounterId = order.encounterId?.trim();
    if (encounterId != null && encounterId.isNotEmpty) {
      return WorkflowActionButton(
        encounterId: encounterId,
        patientId: order.patientId,
        orderId: order.id,
        stage: order.status,
        displayNextStep: label,
        sourceModule: 'radiology',
        compact: true,
        onBeforeNavigate: () => /* optional: ensure selectOrder if needed */,
      );
    }
    return AppButton(
      label: label,
      compact: true,
      onPressed: () => unawaited(
        _openRadiologyDetailDialog(context, ref, state, order, ...),
      ),
    );
  }
}
```

When `WorkflowActionButton` does not resolve (registry returns null), fall back to `AppButton`/`TextButton` with `_nextActionLabel` that calls `_openRadiologyDetailDialog`. Stop event propagation so row tap is not double-fired.

Update `_radiologyNextActionColumn` to use `_RadiologyNextActionCell` with `alwaysVisible: true`.

**Catalog:**

```dart
onRowSelected: (RadiologyCatalogTest item) {
  _openEditOfferingDialog(context, item);
},
```

### Mobile item builder — worklist

Refactor `_RadiologyOrderListTile` to accept `RadiologyWorkbenchView` (or read from `state.query.view`) and mirror desktop priority:

- Patients view: patient two-line (`AppListItemText`), study, status badge, `_RadiologyNextActionCell`
- Orders view: order id line, patient, study, status, next-action button

Pattern after `_RadiologyOrderListTile` + `EmergencyCaseCell` mobile parity in `emergency_workspace_page.dart`.

---

## Implementation Steps

### 1. Shared l10n (`frontend/lib/l10n/app_en.arb` only)

Add if missing:

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run codegen (`flutter gen-l10n` or project equivalent). Use `commonTableSettingsTitle` instead of `radiologyTableColumnsTitle` for the Settings **modal title** (button stays `commonTableSettingsActionLabel`).

### 2. Worklist table — `radiology_workspace_page.dart` + `radiology_workspace_page.detail_cells.dart`

1. Add `_radiologyWorklistSearchMatcher` in `detail_cells.dart`.
2. Refactor `_patientViewWorklistColumns` to **exactly 5** columns: reorder to `status` before `next_action`.
3. Refactor `_orderViewWorklistColumns` to **exactly 5** columns: drop `priority` to `columnChoices`; reorder `status` / `next_action`.
4. Update `_radiologyPatientNameColumn` to use `AppListItemText` (name + `patientId` subtitle).
5. Replace `_radiologyNextActionColumn` cell builder with `_RadiologyNextActionCell` (`alwaysVisible: true`).
6. Update `_optionalRadiologyWorklistColumns` — ensure demoted columns listed above; no `next_action` or `status` here.
7. Pass `RadiologyDeskSection section` into `_RadiologyOrderBoard`; wire `columnVisibilityStorageKey` and `columnWidthStorageKey`.
8. Wire search chrome l10n keys per Search chrome section.
9. Rewrite `_RadiologyOrderListTile` / `mobileItemBuilder` for field and action parity.
10. Explicitly set `displayMode: AppListTableDisplayMode.adaptive` on worklist `AppListTable` (optional but document intent).

### 3. Catalog table — `radiology_workspace_page.configurations.dart`

1. Add `columnVisibilityStorageKey: 'radiology_catalog_tests'` and `columnWidthStorageKey: 'radiology_catalog_cw_tests'`.
2. Standardize search/settings modal titles (`commonAdvancedFiltersTitle`, `commonTableSettingsTitle`).
3. Reduce `_defaultColumns` to 5 data columns per Column plan; remove `_offeringSelectionColumn` and `_testActionsColumn` from defaults.
4. Fix `name` column — subtitle must not merge unrelated `effectiveId` + `code`; use `code` only as subtitle or drop subtitle.
5. Add `onRowSelected` → `_openEditOfferingDialog`.
6. Keep selection checkbox and `_testActionButtons` in `mobileItemBuilder` only.

### 4. Preserve domain behavior

- Do **not** remove tab-toolbar refresh, view toggle, request imaging, or configurations actions.
- Keep `_applyStageForSection` tab → stage mapping and URL `section` query sync (`_updateUrlForSection`).
- Keep `_openRadiologyDetailDialog` → `selectOrder` → workflow detail flow and permission gating (`_workRequirement`, `_requestRequirement`).
- Keep advanced filter groups and `controller.applyStage/applyStatus/applyModality/applyPriority/applyBillingGate/applyOrderedDate` wiring.

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | All tables |
| `AppListTableColumnVisibilityController` | `app_list_table.dart` (via components) | Session column visibility |
| `AppListTableDisplayMode` | `app_list_table.dart` | Adaptive layout |
| `AppWorkspaceStatusBadge` | `components.dart` | Status column |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Patient two-line cells |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Next-action when `encounterId` present |
| `AppButton` | `components.dart` | Fallback next-action / catalog mobile actions |
| `_openRadiologyDetailDialog` | `radiology_workspace_page.dart` | Row tap + next-action destination |

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` |
| Modify | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.detail_cells.dart` |
| Modify | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/radiology/presentation/radiology_workspace_page_test.dart` |
| Optional create | `frontend/lib/features/radiology/presentation/widgets/radiology_next_action_cell.dart` (if extracting widget) |

Do **not** delete `radiologyTableColumnsTitle` from arb — stop using it for modal title only.

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule).
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`.
- Keep existing radiology next-action label keys (`radiologyNextActionConfirmBilling`, etc.) for per-row button text.
- Column header for next action may stay `radiologyNextActionColumnLabel` ("Next action") or add `commonNextActionLabel` if other modules use it.

---

## Database Migrations

**No database migrations required — schema unchanged.**

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/radiology/
```

---

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome (no export/refresh in search bar)
- [ ] Advanced filters modal title is "Advanced filters"; Settings modal title is "Table Settings"
- [ ] Column visibility persists for session per `columnVisibilityStorageKey` (worklist per section+view; catalog `radiology_catalog_tests`)
- [ ] ≤5 default columns per table; row number automatic
- [ ] Worklist: `status` column second-from-right; `next_action` rightmost with explicit per-row verb labels
- [ ] Orders view has exactly 5 columns (priority hidden by default)
- [ ] Row tap opens `_openRadiologyDetailDialog`
- [ ] Next-action control opens detail dialog or workflow route (not generic `/radiology` home)
- [ ] Mobile list shows same priority fields, status badge, and interactive next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions (`radiologyWrite`, `clinicalWrite`)
- [ ] Existing tests updated: `columnVisibilityStorageKey` expectations, modal titles if asserted

Update `radiology_workspace_page_test.dart`:

- Assert `columnVisibilityStorageKey` contains section + view (e.g. `radiology_worklist_patients`).
- Assert `columnVisibilityTitle` / `advancedFilterTitle` use shared keys after migration.
- Assert orders view table has `columns.length == 5`.

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every `AppListTable` on the Radiology workspace and configurations dialog
- [ ] Domain logic preserved (tabs, stages, view toggle, detail workflow, catalog CRUD)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/radiology/` passes
