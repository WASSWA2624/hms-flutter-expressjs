# Standardize Pharmacy Tables

## Objective

Refactor every `AppListTable` on the Pharmacy workspace (`/pharmacy`, `PharmacyWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation.

**Route:** `/pharmacy` → `PharmacyWorkspacePage` (`frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`)

**Deep link:** `?section=<tab>` where tab values are `queue`, `in-progress`, `pending-payment`, `completed`, `all` (also accepts aliases like `ready`, `dispense`, `payment`, `dispensed`). Inventory deep link `?section=inventory` opens catalog dialog — preserve as-is.

**Tabs (`PharmacyDeskSection`):**

| Enum | Tab label (l10n) | Server filter |
|------|------------------|---------------|
| `queue` | `pharmacySummaryReadyLabel` → "Ready" | `PharmacyOrderFilter.ready` |
| `inProgress` | `pharmacySummaryPartialLabel` → "Partial" | `PharmacyOrderFilter.partial` |
| `pendingPayment` | `pharmacyFilterPendingPayment` | `PharmacyOrderFilter.pendingPayment` |
| `completed` | `pharmacySummaryCompletedLabel` | `PharmacyOrderFilter.completed` |
| `allOrders` | `pharmacyFilterAll` | `PharmacyOrderFilter.all` |

**Realtime:** `pharmacyWorkspaceControllerProvider` (`frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart`) already listens to `RealtimeEventGroups.pharmacyWorkspace` via `listenForRealtimeRefresh`. Table refactors must keep provider-driven data — never mutate rows in widgets.

---

## Current State (from audit)

### Table 1 — `_PharmacyQueuePanel`

| Attribute | Value |
|-----------|-------|
| File | `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (~L528–665) |
| Entity | `PharmacyOrder` |
| Binding | Main worklist; one instance per desk tab (`PharmacyDeskSection`) |
| Provider | `pharmacyWorkspaceControllerProvider` → `state.workbench.orders` |
| Row detail | `onRowSelected` → `_openPharmacyDetailDialog` (~L808) opens `AppDialog` with `_PharmacyDetailPanel` |

**Current default columns (7 — exceeds budget):**

| # | id | Label key | Field / builder |
|---|-----|-----------|---------------|
| 1 | *(none)* | `pharmacyPatientColumnLabel` | `order.displayTitle` via `_PharmacyOrderPatientCell` |
| 2 | *(none)* | `pharmacyOrderColumnLabel` | `order.displayId` |
| 3 | *(none)* | `pharmacyLocationFieldLabel` | `_locationLabel(context, order)` |
| 4 | *(none)* | `pharmacyItemsColumnLabel` | `order.itemCount` |
| 5 | *(none)* | `pharmacyDispenseColumnLabel` | `_dispenseProgressLabel` |
| 6 | `billing` | `pharmacyPaymentColumnLabel` | `_billingGateLabel` |
| 7 | *(none)* | `pharmacyStatusColumnLabel` | `AppWorkspaceStatusBadge` via `_orderStatus` |

**`columnChoices` (8 optional, hidden by default):** `patient_id`, `encounter`, `ordered_at`, `priority`, `prescriber`, `order_source`, `pending_attestation`, `remaining_qty` — see `_optionalPharmacyWorklistColumns` (~L2773).

**Per-tab column override (`_columnsForSection`, ~L2678):** `pendingPayment` tab replaces columns 5–7 with a single `ordered_at` optional column (`base.take(4)` + `ordered_at`), yielding 5 columns but **no status** and **no next-action**.

**Search chrome gaps:**

- `matcher: (_, _) => true` — search is server-only; does not match hidden `columnChoices` client-side.
- `advancedFilterButtonLabel`: `pharmacyQueueFilterLabel` ("Filters") ✓
- `advancedFilterTitle`: `pharmacyFiltersSemanticLabel` ("Pharmacy queue filters") ✗ — must be **Advanced filters**
- Missing `columnVisibilityTitle` (Table Settings modal title)
- `columnVisibilityStorageKey`: `'pharmacy_${section.name}'` ✓ (per tab)
- `columnWidthStorageKey`: `'pharmacy_cw_${section.name}'` ✓

**Other gaps:**

- No `next_action` column; workflow actions only in detail dialog (`_PharmacyActionPanel`)
- Mobile tile (`_PharmacyOrderListTile`) shows status/billing/dispense but **no next-action control**
- Patient + order ID are separate columns (merge eligible via two-line `AppListItemText`)
- `displayMode` defaults to adaptive ✓

---

### Table 2 — `_MedicationItemsPanel`

| Attribute | Value |
|-----------|-------|
| File | same file (~L1033–1139) |
| Entity | `PharmacyOrderItem` |
| Binding | Inside `_PharmacyDetailPanel` (detail dialog content) |
| Row detail | **None** — no `onRowSelected` |

**Current columns (5 — at budget but non-compliant chrome):**

| # | id | Label key | Field / builder |
|---|-----|-----------|---------------|
| 1 | *(none)* | `pharmacyMedicationColumnLabel` | `_MedicationCell` (name + instructions two-line) |
| 2 | *(none)* | `pharmacyDoseColumnLabel` | `item.doseLine` |
| 3 | *(none)* | `pharmacyQuantityColumnLabel` | `item.quantityLine` |
| 4 | *(none)* | `pharmacyLinePriceColumnLabel` | `_MedicationPriceCell` |
| 5 | *(none)* | `pharmacyLineActionsColumnLabel` | `_MedicationLineActions` (Map stock / price toggles) |

**Gaps:**

- No `AppListTableSearch` (no search chrome)
- No `columnVisibilityController` / storage keys
- No column `id`s on any column
- Dose is separate from medication despite `_MedicationCell` already supporting instructions subtitle — dose could stay separate (distinct field) or move to `columnChoices`
- Line actions are inline multi-button `Wrap`, not a single explicit next-action
- No `onRowSelected` for line-level detail (acceptable if line actions suffice; add row tap only if a detail surface exists)

---

### Table 3 — `_DrugStockPanel`

| Attribute | Value |
|-----------|-------|
| File | same file (~L1464–1615) |
| Entity | `PharmacyDrug` |
| Binding | **Defined but never instantiated** in current UI — drug stock is surfaced via `openPharmacyCatalogDialog` / `pharmacy_catalog_panel.dart` instead |

**Current columns (3):**

| # | id | Label key | Field / builder |
|---|-----|-----------|---------------|
| 1 | *(none)* | `pharmacyDrugColumnLabel` | `_DrugCell` (name + code/id two-line) |
| 2 | *(none)* | `pharmacyAvailableColumnLabel` | `item.availableQuantity` |
| 3 | *(none)* | `pharmacyStockStatusColumnLabel` | `AppWorkspaceStatusBadge` via `_stockStatus` |

**Gaps:**

- No `columnVisibilityController` / storage keys
- `advancedFilterButtonLabel` / `advancedFilterTitle`: both `pharmacyDrugFiltersSemanticLabel` ("Drug stock filters") — must be **Filters** / **Advanced filters**
- `matcher: (_, _) => true` — server-only search via `controller.applyDrugSearch`
- No `onRowSelected` / detail dialog
- No workflow next-action (stock is reference data — up to 5 data columns OK)
- Dead code path — standardize in place; do **not** delete unless compilation proves unused after audit

---

### Table 4 — `_ReturnMedicationsTable`

| Attribute | Value |
|-----------|-------|
| File | same file (~L2065–2286) |
| Entity | `_LineEditState` (wraps `PharmacyOrderItem` + `quantityController`) |
| Binding | Inside `_ReturnDialog` (~L1903), opened from `_PharmacyActionPanel` |
| Row detail | Checkbox selection + `onEditLine` via tertiary button |

**Current columns (6 — exceeds budget):**

| # | id | Label key | Field / builder |
|---|-----|-----------|---------------|
| 1 | `select` | `''` (checkbox header) | `_selectionColumn()` |
| 2 | `medication` | `pharmacyMedicationColumnLabel` | `_MedicationCell` |
| 3 | `dose` | `pharmacyDoseColumnLabel` | `line.item.doseLine` |
| 4 | `quantity` | `pharmacyQuantityColumnLabel` | `line.item.quantityLine` |
| 5 | `return_quantity` | `pharmacyReturnQuantityColumnLabel` | `_returnQuantityLabel(line)` |
| 6 | `actions` | `pharmacyLineActionsColumnLabel` | `AppButton.tertiary` Edit line |

**Gaps:**

- No search chrome (dialog edit table — add minimal search if lines can exceed ~10 rows; otherwise document exemption with inline search matcher over medication/dose)
- `displayMode: AppListTableDisplayMode.table` — switch to `adaptive` with `mobileItemBuilder` parity (mobile builder exists ✓)
- 6 columns including selection — must reduce to ≤5
- No `columnVisibilityStorageKey` (single-use dialog table — use `'pharmacy_return_lines'` if adding Settings)

---

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, `AppListTableColumn`, `AppListTableColumnVisibilityController`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (~L545): Filters/Settings chrome wiring pattern
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` + `WorkflowActionButton` (~L529)
- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` — `_optionalWorklistColumns` next-action with `WorkflowActionButton` (~L783); status + billing column patterns
- `prompt.md` — normative contract

**Pharmacy-specific action handlers to reuse (do not duplicate):**

| Action | Handler | Dialog |
|--------|---------|--------|
| Record payment | `_openRecordPaymentDialog` | `showClinicalRequestBillingDialog` |
| Dispense | `_openDispenseDialog` | `_DispenseDialog` |
| Attest | `_openAttestDialog` | `_AttestDialog` |
| Return | `_openReturnDialog` | `_ReturnDialog` |
| Cancel | `_openCancelDialog` | `_CancelOrderDialog` |
| Row detail | `_openPharmacyDetailDialog` | `AppDialog` + `_PharmacyDetailPanel` |

**Next-action label resolver (create `_pharmacyOrderNextActionLabel` + `_PharmacyOrderNextActionButton`):**

Priority order (first match wins):

1. `order.requiresPaymentBeforeDispense` && payment not confirmed → `pharmacyRecordPaymentAction` ("Record payment") → `_openRecordPaymentDialog`
2. `order.canAttestDispense` || `workflow.nextActions.canAttestDispense` → `pharmacyAttestAction` ("Attest") → `_openAttestDialog` (after loading workflow via `selectOrder`)
3. `order.canPrepareDispense` && !payment blocked → `pharmacyDispenseAction` ("Dispense") → `_openDispenseDialog`
4. `order.canReturn` → `pharmacyReturnAction` ("Return") → `_openReturnDialog`
5. `order.canCancel` → `pharmacyCancelOrderAction` ("Cancel order") → `_openCancelDialog`
6. `!order.hasBillingGate` → `pharmacyNextActionConfirmBilling` ("Confirm billing") → `_openRecordPaymentDialog`
7. Fallback (read-only) → open detail dialog (`_openPharmacyDetailDialog`)

Use `AppButton.tertiary` with explicit label for pharmacy-native dialogs (same pattern as lab when `WorkflowActionButton` is not appropriate). `WorkflowActionButton` with `sourceModule: 'pharmacy'` is registered for cross-module `DISPENSE_MEDICINE` routing only — prefer direct dialog handlers for in-module worklist actions.

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|----------------------------------|----------------------------|
| `_PharmacyQueuePanel` | Ready (`queue`) | `PharmacyOrder` | patient, location, dispense_progress, status, next_action | `pharmacy_queue` |
| `_PharmacyQueuePanel` | In progress | `PharmacyOrder` | patient, location, dispense_progress, status, next_action | `pharmacy_inProgress` |
| `_PharmacyQueuePanel` | Pending payment | `PharmacyOrder` | patient, billing, ordered_at, status, next_action | `pharmacy_pendingPayment` |
| `_PharmacyQueuePanel` | Completed | `PharmacyOrder` | patient, location, dispense_progress, status, next_action | `pharmacy_completed` |
| `_PharmacyQueuePanel` | All orders | `PharmacyOrder` | patient, location, items, status, next_action | `pharmacy_allOrders` |
| `_MedicationItemsPanel` | Detail dialog | `PharmacyOrderItem` | medication, dose, quantity, line_price, line_action | `pharmacy_order_items` |
| `_DrugStockPanel` | *(unused panel)* | `PharmacyDrug` | drug, available_qty, stock_status | `pharmacy_drug_stock` |
| `_ReturnMedicationsTable` | Return dialog | `_LineEditState` | medication, quantity, return_qty, selection, edit_line | `pharmacy_return_lines` |

Use stable keys without `${section.name}` if you unify column sets across tabs; if per-tab defaults differ materially, keep per-section keys as today.

### Column plan — `_PharmacyQueuePanel` (default tabs: queue, inProgress, completed)

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `patient` | `pharmacyPatientColumnLabel` | `order.displayTitle` + `order.displayId` subtitle | `AppListItemText` two-line — one semantic patient field |
| 2 | `location` | `pharmacyLocationFieldLabel` | `_locationLabel` | |
| 3 | `dispense_progress` | `pharmacyDispenseColumnLabel` | `_dispenseProgressLabel` | Tab `allOrders`: use `items` (`pharmacyItemsColumnLabel`) instead |
| 4 | `status` | `pharmacyStatusColumnLabel` | `_orderStatus` → `AppWorkspaceStatusBadge` | Second from right |
| 5 | `next_action` | `pharmacyLineActionsColumnLabel` or new `pharmacyNextActionColumnLabel` | `_PharmacyOrderNextActionButton` | Explicit verb; opens same dialog as detail actions |

**Pending payment tab override:**

| Position | Column id | Label | Source |
|----------|-----------|-------|--------|
| 1 | `patient` | patient | two-line patient + order id |
| 2 | `billing` | `pharmacyPaymentColumnLabel` | `_billingGateLabel` |
| 3 | `ordered_at` | `pharmacyOrderedAtColumnLabel` | `_dateTimeLabel(order.orderedAt)` |
| 4 | `status` | status | `_orderStatus` |
| 5 | `next_action` | next action | Record payment / Confirm billing |

**Move to `columnChoices`:** `order` (merged into patient), `items`, `dispense_progress` (when not default), `billing`, `encounter`, `priority`, `prescriber`, `order_source`, `pending_attestation`, `remaining_qty`, `patient_id`, `ordered_at` (non-payment tabs).

### Column plan — `_MedicationItemsPanel`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `medication` | medication | `_MedicationCell` | name + instructions |
| 2 | `dose` | dose | `item.doseLine` | |
| 3 | `quantity` | quantity | `item.quantityLine` | |
| 4 | `line_price` | line price | `_MedicationPriceCell` | |
| 5 | `line_action` | actions | Single primary `_MedicationLineActions` button | Show highest-priority action only (map stock > price switch); extras in `columnChoices` or detail on row tap |

### Column plan — `_DrugStockPanel`

| Position | Column id | Label | Source |
|----------|-----------|-------|--------|
| 1 | `drug` | drug | `_DrugCell` |
| 2 | `available` | available | `availableQuantity` |
| 3 | `stock_status` | stock status | `AppWorkspaceStatusBadge` |

Optional `columnChoices`: `code`, `form`, `strength`, `unit_price`, `storage_location` if fields exist on `PharmacyDrug`.

### Column plan — `_ReturnMedicationsTable`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `select` | `''` | checkbox | Keep if bulk return requires it; counts toward 5 |
| 2 | `medication` | medication | `_MedicationCell` + dose as `bodySmall` subtitle | Merge dose into medication column |
| 3 | `quantity` | quantity | `item.quantityLine` | |
| 4 | `return_quantity` | return qty | `_returnQuantityLabel` | |
| 5 | `edit_line` | actions | Edit line button | `alwaysVisible: true`; remove separate dose + actions columns |

### Search chrome (per table)

**`_PharmacyQueuePanel`:**

- Add `_pharmacyOrderSearchMatcher(BuildContext, PharmacyOrder, String query)` matching: `displayTitle`, `displayId`, `patientId`, `encounterId`, `status`, `location`, `priority`, `prescriberDisplayName`, `orderSource`, `effectivePaymentStatus`, `firstPendingBatchRef`, numeric fields as strings, and all `columnChoices` fields.
- `advancedFilterButtonLabel`: use `pharmacyQueueFilterLabel` ("Filters") or add `commonFiltersActionLabel` = "Filters"
- `advancedFilterTitle`: add `commonAdvancedFiltersTitle` = "Advanced filters" to `app_en.arb` and use it
- `columnVisibilityLabel`: `l10n.commonTableSettingsActionLabel`
- `columnVisibilityTitle`: add `commonTableSettingsTitle` = "Table Settings" to `app_en.arb` (or hardcode per mortuary pattern until shared key exists)
- Keep existing `filterGroups` and date filter wiring

**`_MedicationItemsPanel`:**

- Add `AppListTableSearch` with matcher over medication label, instructions, dose, quantity, price text
- Filters: omit or single "Show cancelled" filter if useful
- Settings: `columnVisibilityStorageKey: 'pharmacy_order_items'`

**`_DrugStockPanel`:**

- Standardize filter labels to Filters / Advanced filters
- Add `columnVisibilityController` + `pharmacy_drug_stock` key
- Client matcher: `displayTitle`, `code`, `displayId`, `stockStatus`, `availableQuantity`

**`_ReturnMedicationsTable`:**

- If `lines.length > 8`, add inline `AppListTableSearch` matcher on medication name + dose
- Otherwise omit search (document in code comment)

### Row interaction

- `_PharmacyQueuePanel`: keep `onRowSelected` → `_openPharmacyDetailDialog`; next-action column must call the same dialog/action handlers
- `_MedicationItemsPanel`: optional `onRowSelected` → expand line or no-op; line_action column mirrors `_MedicationLineActions` primary action
- `_DrugStockPanel`: add `onRowSelected` → `openPharmacyCatalogDialog(context, ref, initialTab: PharmacyCatalogTab.drugs)` or `PharmacyDrugEditDialog` if edit permission
- `_ReturnMedicationsTable`: row tap toggles selection OR opens `_ReturnLineEditDialog`; edit_line column opens same dialog

---

## Implementation Steps

### 1. Shared helpers — `pharmacy_workspace_page.dart` (bottom of file)

1. Add `_pharmacyOrderSearchMatcher` and wire into `_PharmacyQueuePanel` search `matcher`.
2. Add `_pharmacyOrderNextActionLabel(BuildContext, PharmacyOrder)` and `_PharmacyOrderNextActionButton` widget (ConsumerWidget) that resolves action + `onPressed` per priority list above.
3. Refactor `_defaultPharmacyWorklistColumns` → max 5 columns with ids; move extras to `_optionalPharmacyWorklistColumns`.
4. Update `_columnsForSection` for `pendingPayment` per target plan.
5. Add `columnVisibilityTitle` on all tables that gain Settings.

### 2. `_PharmacyQueuePanel` (~L528)

- Reduce columns to ≤5 per tab (see Target Architecture)
- Add `next_action` column with `_PharmacyOrderNextActionButton`
- Wire search matcher
- Fix `advancedFilterTitle` → "Advanced filters"
- Update `_PharmacyOrderListTile` mobile builder: show same 3 data fields + status badge + next-action button

### 3. `_MedicationItemsPanel` (~L1033)

- Add column `id`s
- Add `AppListTableSearch` + `columnVisibilityController` with key `pharmacy_order_items`
- Refactor `_MedicationLineActions` to expose a single primary action for column 5; keep full `Wrap` in mobile builder footer or row expansion
- Ensure `displayMode: AppListTableDisplayMode.adaptive` (explicit)

### 4. `_DrugStockPanel` (~L1464)

- Add `columnVisibilityController`, storage keys, standardized filter titles
- Add client search matcher (keep `onSubmitted` server sync if desired; matcher for local highlight/filter of current page)
- Add `onRowSelected` handler
- Add `mobileItemBuilder` parity if missing fields

### 5. `_ReturnMedicationsTable` (~L2065)

- Merge dose into medication column; drop standalone dose column
- Reduce to 5 columns: select, medication (with dose subtitle), quantity, return_quantity, edit_line
- Set `displayMode: AppListTableDisplayMode.adaptive`
- Align mobile builder with desktop columns

### 6. l10n — `frontend/lib/l10n/app_en.arb`

Add if missing:

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"pharmacyNextActionColumnLabel": "Next action"
```

Prefer shared keys for Filters/Settings modal titles. Keep existing `pharmacyQueueFilterLabel` if it already equals "Filters".

### 7. Tests — `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart`

Update/add:

- Queue table has ≤5 `DataColumn` labels (excluding auto row number)
- Pending payment tab shows billing + ordered_at + status (adjust from current "Ordered at" only assertion)
- Mobile breakpoint still uses list tiles with status visible
- Search matcher unit test (extract matcher to top-level function for testability)
- Next-action button present on worklist row when order is `ORDERED`

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` | `package:hosspi_hms/shared/components/components.dart` | All tables |
| `AppListTableColumn` | same | Column definitions |
| `AppListTableSearch` | same | Search chrome |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableColumnVisibilityMemory` | same | Backing store for controller |
| `AppWorkspaceStatusBadge` | same | Status columns |
| `AppListItemText` | same | Two-line patient/drug cells |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_actions.dart` | Only for cross-module dispense routing |
| `AppButton.tertiary` | `package:hosspi_hms/shared/components/components.dart` | In-module next-action controls |
| `showAppDialog` / `AppDialog` | `package:hosspi_hms/shared/components/components.dart` | Detail + workflow dialogs |

---

## Files to Create / Modify / Delete

| File | Action |
|------|--------|
| `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` | **Modify** — all four tables + helpers |
| `frontend/lib/l10n/app_en.arb` | **Modify** — shared table chrome keys |
| `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart` | **Modify** — column/chrome assertions |
| `frontend/test/features/pharmacy/presentation/pharmacy_order_search_matcher_test.dart` | **Create** (optional) — matcher unit tests |

Do **not** modify `pharmacy_catalog_panel.dart` in this pass (separate catalog dialog scope) unless `_DrugStockPanel` is deleted and its behavior merged.

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule)
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`
- Run `flutter gen-l10n` after arb changes

---

## Database Migrations

No database migrations required — schema unchanged.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/pharmacy/
```

---

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome (where search chrome applies)
- [ ] Column visibility persists for session per table key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status + next-action labels on `_PharmacyQueuePanel`
- [ ] Row tap opens detail dialog on queue table
- [ ] Mobile list shows same priority fields + status + next action on queue table
- [ ] Realtime refresh still updates rows after mutations/events (controller unchanged)
- [ ] Permissions still gate write actions via `AccessRequirement` / `AppAccessActionGate`
- [ ] Pending payment tab column set matches target (billing, ordered_at, status, next_action)
- [ ] Return dialog table ≤5 columns

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen
- [ ] Domain logic preserved (dispense, attest, return, billing, permissions, deep links, tab filters)
- [ ] Analyze clean; tests pass
