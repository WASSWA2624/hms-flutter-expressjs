# Standardize Laboratory Tables

## Objective

Refactor every `AppListTable` on the Laboratory workspace (`/lab`, `LabWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only** on `LabWorkspacePage` and its directly hosted dialogs (`_LabConfigurationsDialog`). Do not rewrite domain APIs, permissions, unrelated tab-toolbar actions (Create Lab Order, Refresh, view toggle, Reference Ranges), or `LabResultEntryDialog` inner tables unless required for compilation.

**Route:** `/lab` — deep-link query parameter is `?section=<value>` (aliases: `panel`, `filter`, `scope`). Also supports `encounterId`, `orderId`, `search` / `q`.

---

## Current State (from audit)

### Table 1 — `_LabWorklistPanel`

| Attribute | Value |
|-----------|-------|
| Widget | `_LabWorklistPanel` |
| File | `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` |
| Entity | `LabOrderSummary` |
| Provider | `labWorkspaceControllerProvider` (`LabWorkspaceController`) |
| Tabs | Single table instance; tab strip switches `LabDeskSection` → `LabQueueScope` via `applyScope` |
| Storage keys | `columnVisibilityStorageKey: 'lab_$sectionName'`, `columnWidthStorageKey: 'lab_cw_$sectionName'` ✓ |
| Row detail | `onRowSelected` → `_openLabDetailDialog` → `LabResultEntryDialog` ✓ |
| `displayMode` | **Missing** — not set (defaults to table-only) |
| Column controller | `AppListTableColumnVisibilityController<LabOrderSummary>` in `_LabWorkspaceContentState` ✓ |

**Tab / view matrix**

| `LabDeskSection` | URL `section` | `LabQueueScope` | l10n tab label | Column set switches on |
|------------------|---------------|-----------------|----------------|------------------------|
| worklist | `worklist` | `all` | `labScopeAll` ("All") | `LabWorkbenchView` |
| collection | `collection` | `collection` | `labScopeCollection` ("Awaiting results") | `LabWorkbenchView` |
| processing | `processing` | `processing` | `labScopeProcessing` ("Processing") | `LabWorkbenchView` |
| verification | `verification` | `results` | `labScopeResults` ("Pending verification") | `LabWorkbenchView` |
| critical | `critical` | `critical` | `labScopeCritical` ("Critical") | `LabWorkbenchView` |
| completed | `completed` | `completed` | `labScopeCompleted` ("Verified") | `LabWorkbenchView` |

`LabWorkbenchView` toggles via tab-toolbar **Orders view** / **Patients view** (`applyView`). Two column builders exist:

**Patients view — `_patientViewWorklistColumns` (9 columns — violates ≤5):**

| # | id | label (l10n) | field / builder |
|---|-----|--------------|-----------------|
| 1 | `patient` | `labPatientColumnLabel` | `patientDisplayName` / `displayTitle` — plain `Text` |
| 2 | `patient_id` | `labPatientIdColumnLabel` | `patientId` |
| 3 | `encounter` | `labEncounterColumnLabel` | `encounterId` |
| 4 | `lab_encounter` | `labLabEncounterColumnLabel` | `_labOrderEncounterLabel` |
| 5 | `source_location` | `labSourceLocationColumnLabel` | `_sourceLocationLabel` (source + location joined) |
| 6 | `orders` | `labOrdersColumnLabel` | `_LabOrderIdentifier` (active count + IDs — merged display) |
| 7 | `entry_status` | `labEntryStatusColumnLabel` | `AppWorkspaceStatusBadge` via `_entryStatus` |
| 8 | `billing` | `labPaymentColumnLabel` | `_labBillingGateLabel` text |
| 9 | `result_status` | `labResultStatusLabel` | `AppWorkspaceStatusBadge` via `_resultStatus` |

**Orders view — `_orderViewWorklistColumns` (5 columns — at limit but wrong layout):**

| # | id | label | field / builder |
|---|-----|-------|-----------------|
| 1 | `orders` | `labOrderColumnLabel` | `_LabOrderIdentifier` |
| 2 | `patient` | `labPatientColumnLabel` | patient name text |
| 3 | `entry_status` | `labEntryStatusColumnLabel` | `_entryStatus` badge |
| 4 | `billing` | `labPaymentColumnLabel` | billing gate text |
| 5 | `result_status` | `labResultStatusLabel` | `_resultStatus` badge |

**Hidden `columnChoices` — `_optionalWorklistColumns`:**

| id | label | notes |
|----|-------|-------|
| `patient_id` | Patient ID | duplicate of data in patient column when two-line used |
| `encounter` | Encounter | |
| `lab_encounter` | Lab encounter | |
| `source_location` | Source location | |
| `tests` | `labTestsColumnLabel` | `testsLabel` |
| `next_action` | `labNextActionColumnLabel` | **`WorkflowActionButton`** — wrongly hidden |

**Search chrome gaps:**

| Issue | Current | Required |
|-------|---------|----------|
| Search matcher | `matcher: (_, _) => true` | Matcher covering all column + `columnChoices` fields |
| Filters button label | `labWorklistFiltersLabel` ("Filters") ✓ | Keep or migrate to shared `commonFiltersActionLabel` |
| Advanced filters modal title | `labWorklistFiltersLabel` ("Filters") | **"Advanced filters"** |
| Settings button label | `commonTableSettingsActionLabel` ("Settings") ✓ | unchanged |
| Settings modal title | `labTableColumnsTitle` ("Lab table columns") | **"Table Settings"** |
| Extra chrome actions | None in search bar ✓ | Refresh/view toggle correctly in tab toolbar |

**Other gaps:**

- Two status columns (`entry_status` + `result_status`) instead of one workflow status column (position 4) + next-action (position 5).
- `next_action` with `WorkflowActionButton` is in `columnChoices` (hidden) instead of default visible rightmost column.
- Patient column lacks `AppListItemText` two-line (name + patient ID).
- `mobileItemBuilder` shows only `_orderStatus` badge; missing result/entry status parity, billing, tests, and `WorkflowActionButton`.
- No `displayMode: AppListTableDisplayMode.adaptive`.

**Workflow next-action labels** (`_nextActionLabel` / `WorkflowActionButton`):

| Condition | Label key |
|-----------|-----------|
| `status == CANCELLED` | `labNextActionCancelled` |
| `hasCriticalResult` | `labNextActionReviewCritical` |
| `verifiableItemCount > 0` | `labNextActionVerify` |
| `ORDERED` / `COLLECTED` | `labNextActionEnterResult` |
| `IN_PROCESS` | `labNextActionVerify` |
| `COMPLETED` | `labNextActionCompleted` |
| default | `labNextActionWatch` |

`WorkflowActionButton` wiring (existing in `columnChoices`):

```dart
WorkflowActionButton(
  encounterId: encounterId,
  patientId: item.patientId,
  orderId: item.id,
  nextStep: item.status,
  sourceModule: 'laboratory',
  compact: true,
)
```

When `encounterId` is empty, falls back to text from `_nextActionLabel`.

**Realtime:** `LabWorkspaceController` uses `RealtimeRefreshMixin`, `WorkspaceFastSync`, and `_syncFromRealtime` — preserve this wiring; table must continue reading from `labWorkspaceControllerProvider`.

---

### Table 2 — `_LabConfigurationsDialog` catalog table

| Attribute | Value |
|-----------|-------|
| Widget | `AppListTable<LabCatalogItem>` inside `_LabConfigurationsDialog` |
| File | same `lab_workspace_page.dart` (~line 1429) |
| Entity | `LabCatalogItem` (non-workflow catalog) |
| Row detail | **Missing** `onRowSelected` |
| Storage keys | **Missing** `columnVisibilityStorageKey` / `columnWidthStorageKey` |
| `displayMode` | **Missing** |

**Tests view default columns (`_defaultColumns`, 5):** `name`, `code`, `category`, `price`, `actions` (inline edit/delete buttons — not a semantic data column).

**Panels view default columns:** same pattern with panel labels.

**Hidden `columnChoices` (`_additionalColumns`):** `specimen`, `kind`, `range`/`tests_count`, `description`.

**Search chrome gaps:** same non-standard modal titles as worklist; matcher uses `item.matchesSearch(query)` ✓.

---

## Reference Implementation

Copy patterns from:

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters/Settings chrome, search matcher, filter groups)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` + `WorkflowActionButton` with `compact: true`
- `prompt.md`

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `_LabWorklistPanel` | All 6 `LabDeskSection` tabs × 2 views | `LabOrderSummary` | See per-view plans below | `lab_<sectionName>` (keep) |
| `_LabConfigurationsDialog` catalog | Tests / Panels radio | `LabCatalogItem` | `name`, `code`, `category`, `price`, context column | `lab_catalog_tests` / `lab_catalog_panels` |

### Column plan — Worklist, **Patients view** (all tabs)

Apply to every tab; tab only changes **which rows** are loaded (scope), not column definitions.

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `patient` | `labPatientColumnLabel` | `patientDisplayName` + `patientId` | `AppListItemText` primary/subtitle |
| 2 | `orders` | `labOrdersColumnLabel` | `_LabOrderIdentifier` | single semantic "orders" field |
| 3 | `tests` | `labTestsColumnLabel` | `testsLabel` | priority triage field |
| 4 | `workflow_status` | `labEntryStatusColumnLabel` or new `labWorkflowStatusColumnLabel` | `order.status` | `AppWorkspaceStatusBadge` via `labStatusBadge` / `_orderStatus` — **one** status column |
| 5 | `next_action` | `labNextActionColumnLabel` | `WorkflowActionButton` | `alwaysVisible: true`; opens workflow action or `_openLabDetailDialog` fallback |

**Move to `columnChoices` (hidden by default):** `patient_id`, `encounter`, `lab_encounter`, `source_location`, `billing`, `entry_status`, `result_status` (retain builders `_entryStatus`, `_resultStatus`, `_billingWorklistColumn` for optional visibility).

### Column plan — Worklist, **Orders view**

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `orders` | `labOrderColumnLabel` | `_LabOrderIdentifier` | |
| 2 | `patient` | `labPatientColumnLabel` | name + `patientId` | `AppListItemText` |
| 3 | `tests` | `labTestsColumnLabel` | `testsLabel` | |
| 4 | `workflow_status` | status label | `labStatusBadge(context, item.status)` | single status |
| 5 | `next_action` | `labNextActionColumnLabel` | `WorkflowActionButton` | same as patients view |

### Column plan — Catalog table (non-workflow)

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `name` | test/panel name label | `name` | |
| 2 | `code` | test/panel code label | `code` | |
| 3 | `category` | `labCategoryLabel` | `category` | |
| 4 | `price` | `clinicalRequestUnitPriceLabel` | `unitPrice` | |
| 5 | `specimen_or_tests` | `labSpecimenTypeLabel` (tests) or `labTestsColumnLabel` (panels) | `specimenType` / `testCount` | fifth data field |

**Remove `actions` from default columns.** Row tap (`onRowSelected`) opens configure dialog (`_openLabTestConfigurationDialog` / `_openLabPanelDialog`). Keep edit/delete in `mobileItemBuilder` trailing and in detail flow.

### Search chrome (per table)

**Worklist `_LabWorklistPanel`:**

```dart
search: AppListTableSearch<LabOrderSummary>(
  controller: searchController,
  semanticLabel: l10n.labSearchLabel,
  hintText: l10n.labSearchHint,
  matcher: _labWorklistSearchMatcher, // implement — see below
  onChanged: onSearchChanged,
  onSubmitted: onSearchSubmitted,
  onClear: onSearchCleared,
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.commonFiltersActionLabel, // add key or keep labWorklistFiltersLabel ("Filters")
  advancedFilterTitle: l10n.commonAdvancedFiltersTitle, // "Advanced filters"
  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
  advancedFilterResetLabel: l10n.opdClearFiltersAction,
  enableDateFilter: false,
  allFieldsLabel: l10n.opdAllFieldsFilterLabel,
  filterGroups: /* keep payment + status groups */,
  filterValue: filterValue,
  hasActiveFilters: filterValue.isActive,
  onFilterChanged: onFilterChanged,
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle, // "Table Settings"
```

Implement `_labWorklistSearchMatcher(BuildContext context, LabOrderSummary item, String query)` covering:

- All fields in `LabOrderSummary.matchesSearch`
- Formatted status labels (`labStatusLabel`, `_entryStatus` label, `_resultStatus` label)
- Billing gate label (`_labBillingGateLabel`)
- Next-action label (`_nextActionLabel`)
- Payment filter values via `clinicalRequestPaymentStatusDisplayLabel`

Keep server-side `applySearch` debounce — matcher filters the current page for instant feedback; server search remains authoritative.

**Catalog table:** same title/label standardization; keep `item.matchesSearch(query)`.

### Row interaction

**Worklist:**

```dart
onRowSelected: (LabOrderSummary order) {
  unawaited(_openLabDetailDialog(context, ref, state, order, canMutate));
},
displayMode: AppListTableDisplayMode.adaptive,
```

`WorkflowActionButton` `onBeforeNavigate` or executor should align with detail dialog actions (result entry, verify, collect sample).

**Catalog:**

```dart
onRowSelected: (LabCatalogItem item) {
  if (showingTests) {
    _openLabTestConfigurationDialog(context, state, item);
  } else {
    _openLabPanelDialog(context, state, item);
  }
},
```

### Mobile item builder — worklist

Mirror desktop priority: patient two-line, order/tests line, workflow status badge, `WorkflowActionButton`. Pattern after `EmergencyCaseCell` + mobile builder in `emergency_workspace_page.dart`. Replace chevron-only trailing with compact action button.

---

## Implementation Steps

### 1. Shared l10n (`frontend/lib/l10n/app_en.arb` only)

Add if missing:

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run codegen (`flutter gen-l10n` or project equivalent). Prefer these shared keys over `labTableColumnsTitle` for Settings modal title.

### 2. Worklist table — `lab_workspace_page.dart`

1. Add `_labWorklistSearchMatcher` function near `_filterWorklistItems`.
2. Refactor `_patientViewWorklistColumns` and `_orderViewWorklistColumns` to return **exactly 5** columns per plans above.
3. Extract `_labWorkflowStatusColumn(BuildContext context)` returning position-4 status badge using `labStatusBadge(context, item.status)` (or tab-aware `_entryStatus` only when clinically necessary — default to order workflow status).
4. Extract `_labNextActionColumn(BuildContext context)` modeled on `emergencyNextActionColumn()`:
   - `id: 'next_action'`, `alwaysVisible: true`
   - `WorkflowActionButton` with `sourceModule: 'laboratory'`
   - Fallback text cell when no `encounterId`
5. Update `_optionalWorklistColumns` — remove `next_action` from here; add demoted columns (`patient_id`, `encounter`, `lab_encounter`, `source_location`, `billing`, `entry_status`, `result_status`).
6. Update `_patientNameWorklistColumn` to use `AppListItemText` (import `frontend/lib/shared/components/app_list_item_text.dart`).
7. Wire search chrome l10n keys per Search chrome section.
8. Set `displayMode: AppListTableDisplayMode.adaptive` on worklist `AppListTable`.
9. Rewrite `mobileItemBuilder` for field/action parity.

### 3. Catalog table — `_LabConfigurationsDialog` in same file

1. Add `columnVisibilityStorageKey: showingTests ? 'lab_catalog_tests' : 'lab_catalog_panels'`.
2. Add `columnWidthStorageKey: showingTests ? 'lab_catalog_cw_tests' : 'lab_catalog_cw_panels'`.
3. Standardize search/settings modal titles.
4. Remove `_actionsColumn` from `_defaultColumns`; move action buttons to `columnChoices` id `actions` with `alwaysVisible: false` OR rely solely on row tap + mobile trailing.
5. Add `onRowSelected` handler.
6. Set `displayMode: AppListTableDisplayMode.adaptive`.

### 4. Preserve domain behavior

- Do **not** remove tab-toolbar refresh, view toggle, create order, or reference ranges actions.
- Keep `_filterWorklistItems` payment/status client filters.
- Keep `columnVisibilityStorageKey: 'lab_$sectionName'` per-tab persistence.
- Keep `_openLabDetailDialog` → `LabResultEntryDialog` flow and permission gating (`AppPermissions.labWrite`).

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | All tables |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableDisplayMode` | `app_list_table.dart` | Adaptive layout |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Status column |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Patient two-line cells |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Next-action column |
| `labStatusBadge` / `labStatusLabel` | `package:hosspi_hms/features/lab/presentation/lab_status_display.dart` | Workflow status formatting |
| `LabResultEntryDialog` | `package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart` | Row detail dialog |

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/lab/presentation/lab_workspace_page_test.dart` (update column count / title expectations) |
| Delete | none |

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only.
- Add: `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`.
- Reuse: `commonTableSettingsActionLabel`, `labWorklistFiltersLabel` (or alias to common Filters key), existing column labels.
- Deprecate use of `labTableColumnsTitle` for Settings modal title (key may remain for backward compatibility).

---

## Database Migrations

No database migrations required — schema unchanged.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/lab/
```

---

## Testing Requirements

- [ ] Worklist: search bar shows only **Filters** and **Settings** trailing actions
- [ ] Advanced filters modal title is **Advanced filters**; Settings modal title is **Table Settings**
- [ ] Patients view: ≤5 default columns; Orders view: ≤5 default columns
- [ ] `next_action` visible by default with `WorkflowActionButton` (not hidden in Settings)
- [ ] Single workflow status column (position 4); no duplicate status badges in defaults
- [ ] Column visibility persists per `lab_<section>` key when switching tabs
- [ ] Row tap opens `LabResultEntryDialog`
- [ ] Mobile list shows patient, order/tests, status, and next action
- [ ] Search matcher finds values in hidden columns (e.g. patient ID via Settings-visible column)
- [ ] Catalog table: row tap opens configure dialog; storage keys per tests/panels
- [ ] Realtime refresh still updates worklist after mutations (controller tests pass)
- [ ] `AppPermissions.labWrite` still gates write actions

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every `AppListTable` on `LabWorkspacePage` (worklist + configurations catalog)
- [ ] Domain logic preserved (scopes, views, permissions, dialogs, pagination, deep links)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/lab/` passes
