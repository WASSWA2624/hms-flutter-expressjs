# Standardize Claims Tables

## Objective

Refactor every `AppListTable` on the Claims workspace (`/claims`, `ClaimsWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation. Preserve tab toolbar primary/secondary actions (Request authorization, Prepare claim, Refresh, insurance catalog actions), summary bar chips, deep-link handling, pagination, and `_openClaimsDetailDialog` content.

## Current State (from audit)

### Screen layout

| Item | Value |
|------|-------|
| Route | `/claims` |
| Page widget | `ClaimsWorkspacePage` |
| Primary file | `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` |
| Controller | `claimsWorkspaceControllerProvider` (`ClaimsWorkspaceController`) |
| Entity | `ClaimsQueueItem` (`frontend/lib/features/claims/domain/entities/claims_entities.dart`) |
| Deep-link query | `section` / `panel` / `tab` via `ClaimsWorkspaceQuery.fromUri`; also `search`, `encounterId`, `patientId`, `action=preauth` |
| Tabs (`ClaimsDeskSection`) | `authorizations`, `activeClaims`, `settled`, `insuranceSetup` |
| l10n tab labels | `claimsSectionAuthorizations`, `claimsSectionActiveClaims`, `claimsSectionSettled`, `claimsSectionInsuranceSetup` |

### Table inventory

There is **one** `AppListTable` widget — `_ClaimsQueuePanel` — reused for three queue tabs. The **Insurance Setup** tab renders `_ClaimsInsuranceSetupPanel` (description text only; **no** `AppListTable`). Standardize the queue table only; do not add a table to Insurance Setup.

| Table widget | Tab / panel | Entity | `columnVisibilityStorageKey` | `columnWidthStorageKey` |
|--------------|-------------|--------|------------------------------|-------------------------|
| `_ClaimsQueuePanel` | Authorizations | `ClaimsQueueItem` | `claims_authorizations` | `claims_cw_authorizations` |
| `_ClaimsQueuePanel` | Active claims | `ClaimsQueueItem` | `claims_activeClaims` | `claims_cw_activeClaims` |
| `_ClaimsQueuePanel` | Settled | `ClaimsQueueItem` | `claims_settled` | `claims_cw_settled` |

### Per-tab current columns (all exceed five-column budget)

**Authorizations** — 6 declared columns in `_columnsForSection` → `ClaimsDeskSection.authorizations`:

| # | id | Label (l10n) | Field | Cell pattern |
|---|-----|--------------|-------|--------------|
| 1 | `auth_reference` | `claimsReferenceColumnLabel` | `displayId` | `Text` |
| 2 | `auth_patient` | `claimsPatientColumnLabel` | `patientDisplayId` | `Text` + `_fallback` |
| 3 | `auth_coverage` | `claimsCoverageColumnLabel` | `coveragePlanDisplayId` | `Text` + `_fallback` |
| 4 | `auth_status` | `claimsStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` via `_statusFor` |
| 5 | `auth_approved_amount` | `claimsAmountColumnLabel` | `authorization.approvedAmount` | `AppFormatters.currency` |
| 6 | `auth_requested_at` | `claimsRequestedAtColumnLabel` | `authorization.requestedAt` | `_dateTimeLabel` |

**Active claims** — 7 declared columns → `ClaimsDeskSection.activeClaims`:

| # | id | Label | Field | Cell pattern |
|---|-----|-------|-------|--------------|
| 1 | `claim_reference` | Reference | `displayId` | `Text` |
| 2 | `claim_patient` | Patient | `patientDisplayId` | `Text` |
| 3 | `claim_coverage` | Coverage | `coveragePlanDisplayId` | `Text` |
| 4 | `claim_invoice` | Invoice | `invoiceDisplayId` | `Text` |
| 5 | `claim_amount` | Amount | `claim.claimAmount` | currency |
| 6 | `claim_status` | Status | `status` | `AppWorkspaceStatusBadge` |
| 7 | `claim_submitted_at` | Submitted at | `claim.submittedAt` | `_dateTimeLabel` |

**Settled** — 8 declared columns → `ClaimsDeskSection.settled`:

| # | id | Label | Field |
|---|-----|-------|-------|
| 1 | `settled_reference` | Reference | `displayId` |
| 2 | `settled_patient` | Patient | `patientDisplayId` |
| 3 | `settled_coverage` | Coverage | `coveragePlanDisplayId` |
| 4 | `settled_invoice` | Invoice | `invoiceDisplayId` |
| 5 | `settled_claim_amount` | Amount | `claim.claimAmount` |
| 6 | `settled_settlement_amount` | Settlement amount | `claim.settlementAmount` |
| 7 | `settled_status` | Status | `status` |
| 8 | `settled_timeline` | Timeline | `timelineAt` |

### Search chrome gaps (`_ClaimsQueuePanel.build`)

| Area | Current | Gap vs `prompt.md` |
|------|---------|---------------------|
| Search matcher | `matcher: (_, _) => true` (server search only) | Must implement matcher covering **all** default + `columnChoices` fields (see Target Architecture) |
| Filters button | `advancedFilterButtonLabel: l10n.claimsFiltersLabel` (`"Filters"`) | OK for label |
| Filters modal title | `advancedFilterTitle: l10n.claimsFiltersLabel` (`"Filters"`) | Must be **Advanced filters** |
| Settings button | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` | OK (`"Settings"`) |
| Settings modal title | **Not set** | Must set `columnVisibilityTitle` to **Table Settings** |
| Column visibility persistence | `columnVisibilityController` + per-section `columnVisibilityStorageKey` | OK; must wire `columnChoices` |
| `columnChoices` | **Not used** | Required to hold hidden columns |
| Extra search chrome actions | None | OK |
| `displayMode` | Default `AppListTableDisplayMode.adaptive` | OK (explicit set optional) |

### Column / interaction gaps

| Gap | Detail |
|-----|--------|
| Column budget | 6–8 columns per tab; must reduce to ≤5 defaults + `columnChoices` |
| Status position | Status is column 4–7 depending on tab; must be **second from right** (column 4 when workflow applies) |
| Next-action column | **Missing** on all tabs; `_detailActions` defines dialogs but table has no action column |
| Row selection | `onRowSelected` → `_openClaimsDetailDialog` | OK |
| Mobile | `_MobileQueueItem` shows reference, status, coverage/invoice subtitle, timeline — **no next-action control** |
| WorkflowActionButton | Not applicable — Claims uses custom dialogs, not shared workflow engine |
| Realtime | `ClaimsWorkspaceController` uses `listenForRealtimeRefresh` + `RealtimeEventGroups.claims` | OK — do not break |

### Domain workflow — next-action labels (from `_detailActions`)

**Authorization rows** (`detail.isAuthorization`):

| Status | Primary next action | Opens |
|--------|---------------------|-------|
| Any (PENDING, APPROVED, DENIED, EXPIRED, PARTIAL) | `l10n.claimsUpdateStatusAction` | `_openAuthorizationStatusDialog` |

**Claim rows** (`detail.isClaim`):

| Status | Primary next action | Opens |
|--------|---------------------|-------|
| `REJECTED` | `l10n.claimsResubmitClaimAction` | `_openSubmitClaimDialog` |
| `SUBMITTED` | `l10n.claimsRecordResponseAction` | `_openClaimResponseDialog` (initial `APPROVED`) |
| `APPROVED` | `l10n.claimsCloseClaimAction` | `_openClaimResponseDialog` (initial `PAID`) |
| `PARTIAL` | `l10n.claimsRecordResponseAction` | `_openClaimResponseDialog` |
| Other (not `PAID`/`CANCELLED`) | `l10n.claimsSubmitClaimAction` | `_openSubmitClaimDialog` |
| `PAID`, `CANCELLED` (Settled tab) | No write action | Omit next-action cell or show read-only detail affordance |

Gate all write next-actions with `AppAccessActionGate(requirement: claimsWorkspaceWriteRequirement, …)` from `frontend/lib/features/claims/presentation/claims_access.dart`. Close-as-paid may additionally need `claimsFinancialApproveRequirement` if detail dialog already gates it — mirror existing detail behavior.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`, `AppListTableColumnVisibilityMemory`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters/Settings chrome, `columnChoices`, `_matchesSearch`, mobile item, next-action text column pattern)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` structure (adapt for Claims with dialog-opening buttons, not `WorkflowActionButton`)
- `prompt.md`

## Target Architecture

### Table inventory (after refactor)

| Table widget | Tab | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` |
|--------------|-----|--------|----------------------------------|------------------------------|
| `_ClaimsQueuePanel` | Authorizations | `ClaimsQueueItem` | Reference, Patient, Coverage, Status, Next action | `claims_authorizations` |
| `_ClaimsQueuePanel` | Active claims | `ClaimsQueueItem` | Reference, Patient, Coverage, Status, Next action | `claims_activeClaims` |
| `_ClaimsQueuePanel` | Settled | `ClaimsQueueItem` | Reference, Patient, Coverage, Settlement amount, Status | `claims_settled` |

Settled rows are terminal (`PAID`/`CANCELLED`); use five data/status columns without a next-action column.

### Column plan — Authorizations

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `auth_reference` | `claimsReferenceColumnLabel` | `displayId` | `alwaysVisible: true` |
| 2 | `auth_patient` | `claimsPatientColumnLabel` | `patientDisplayId` | Use `AppListItemText` if secondary tier needed (single field) |
| 3 | `auth_coverage` | `claimsCoverageColumnLabel` | `coveragePlanDisplayId` | |
| 4 | `status` | `claimsStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` via `_statusFor` |
| 5 | `next_action` | `claimsNextActionColumnLabel` (add) | derived | Explicit verb button → `_openAuthorizationStatusDialog` |

**`columnChoices` (hidden by default):** `auth_approved_amount`, `auth_requested_at`

### Column plan — Active claims

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `claim_reference` | Reference | `displayId` | `alwaysVisible: true` |
| 2 | `claim_patient` | Patient | `patientDisplayId` | |
| 3 | `claim_coverage` | Coverage | `coveragePlanDisplayId` | |
| 4 | `status` | Status | `status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | Next action (add l10n) | derived | Status-specific label per table above |

**`columnChoices`:** `claim_invoice`, `claim_amount`, `claim_submitted_at`

### Column plan — Settled

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `settled_reference` | Reference | `displayId` | `alwaysVisible: true` |
| 2 | `settled_patient` | Patient | `patientDisplayId` | |
| 3 | `settled_coverage` | Coverage | `coveragePlanDisplayId` | |
| 4 | `settled_settlement_amount` | Settlement amount | `claim.settlementAmount` | numeric |
| 5 | `status` | Status | `status` | `AppWorkspaceStatusBadge` — rightmost |

**`columnChoices`:** `settled_invoice`, `settled_claim_amount`, `settled_timeline`

### Search chrome (all queue tabs)

Refactor `_ClaimsQueuePanel` `AppListTableSearch`:

```dart
matcher: (ClaimsQueueItem item, String query) =>
    _claimsQueueSearchMatcher(context, l10n, section, item, query),
```

Implement `_claimsQueueSearchMatcher` in `claims_workspace_page.dart` (or a dedicated `claims_workspace_table.dart` part file if the page grows) to lowercase-match **every** searchable field for the active section, including hidden `columnChoices` fields:

- `displayId`, `patientDisplayId`, `coveragePlanDisplayId`, `invoiceDisplayId`
- Formatted status label (`_statusLabel`)
- Formatted currency amounts (`approvedAmount`, `claimAmount`, `settlementAmount`)
- Formatted dates (`requestedAt`, `submittedAt`, `timelineAt`)
- Kind label (`claimsAuthorizationTypeLabel` / `claimsClaimTypeLabel`)

Keep `onSubmitted` / `onClear` calling `controller.applySearch` (server-side search via `ClaimsRepositoryImpl.listQueue` `search` query param) **and** ensure the matcher supports local filtering parity for tests/offline rows.

Standardize chrome:

| Control | Wiring |
|---------|--------|
| Filters label | `advancedFilterButtonLabel: l10n.commonFiltersActionLabel` (add key `"Filters"`) or keep `claimsFiltersLabel` if already `"Filters"` |
| Filters modal title | `advancedFilterTitle: l10n.commonAdvancedFiltersTitle` (add key `"Advanced filters"`) |
| Settings label | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` |
| Settings modal title | `columnVisibilityTitle: l10n.commonTableSettingsTitle` (add key `"Table Settings"`) |

Preserve existing filter groups (`_claimsQueueFilterKey`, `_claimsFilterChoicesForSection`, `onFilterChanged` → `controller.applyFilter`).

Wire `columnChoices` to the **full** column list per section; pass `columns:` as the ≤5 default-visible subset (or pass all columns and mark defaults via visibility controller initial state — follow `AppListTable` + Mortuary pattern: `columns` = visible defaults, `columnChoices` = superset).

### Next-action column implementation

Add a helper mirroring Emergency's column factory:

```dart
AppListTableColumn<ClaimsQueueItem> _claimsNextActionColumn(
  BuildContext context,
  WidgetRef ref,
  ClaimsWorkspaceState state,
  ClaimsDeskSection section,
) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: 'next_action',
    label: context.l10n.claimsNextActionColumnLabel,
    alwaysVisible: true,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) {
      return _ClaimsNextActionButton(
        item: item,
        section: section,
        state: state,
      );
    },
  );
}
```

`_ClaimsNextActionButton` must:

1. Resolve label via `_claimsNextActionLabel(l10n, item)` using the status table above.
2. Wrap in `AppAccessActionGate(requirement: claimsWorkspaceWriteRequirement, …)`.
3. On press, open the **same** dialog as `_detailActions` (not generic navigation).
4. For Settled/terminal rows, return `SizedBox.shrink()` or a non-interactive em dash.

Do **not** use `WorkflowActionButton` — Claims is not on the shared workflow rail.

### Row interaction

- Keep `onRowSelected: (item) => unawaited(_openClaimsDetailDialog(context, ref, state, item))`.
- Next-action column must invoke the same dialog entry points as `_detailActions` (`_openAuthorizationStatusDialog`, `_openSubmitClaimDialog`, `_openClaimResponseDialog`).
- Do not duplicate `_ClaimsDetailContent`; reuse existing dialog.

### Mobile (`_MobileQueueItem`)

Update to mirror desktop priority fields:

- Row 1: kind icon + reference (`displayId`) + `AppWorkspaceStatusBadge`
- Row 2: patient + coverage (`AppListItemText` or existing subtitle pattern)
- Row 3: primary next-action `TextButton` (same handler as column) when applicable; otherwise timeline date
- Entire card remains tappable via `onRowSelected`

### Realtime (preserve)

Table reads `state.queue` from `ref.watch(claimsWorkspaceControllerProvider)`. Controller already calls `listenForRealtimeRefresh(events: RealtimeEventGroups.claims, onRefresh: _syncFromRealtime)`. Do not mutate table data locally after mutations — rely on controller refresh/`_afterMutation`.

## Implementation Steps

### 1. Extract column builders (optional but recommended)

In `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` (or new `claims_workspace_table.dart` imported by the page):

- Add `_defaultColumnsForSection` returning ≤5 columns.
- Add `_allColumnsForSection` returning defaults + `columnChoices` extras.
- Add `_claimsQueueSearchMatcher`, `_claimsNextActionLabel`, `_ClaimsNextActionButton`, `_claimsNextActionColumn`.

### 2. Refactor `_columnsForSection`

Replace the current switch bodies so each section returns **at most 5** columns with status at index 3 (0-based: position 4) and `next_action` at index 4 for Authorizations and Active claims.

Move removed columns into `columnChoices` only:

| Section | Move to `columnChoices` |
|---------|-------------------------|
| Authorizations | `auth_approved_amount`, `auth_requested_at` |
| Active claims | `claim_invoice`, `claim_amount`, `claim_submitted_at` |
| Settled | `settled_invoice`, `settled_claim_amount`, `settled_timeline` |

Preserve existing `sortComparator` and `cellBuilder` logic when relocating columns.

### 3. Wire `AppListTable` in `_ClaimsQueuePanel`

```dart
return AppListTable<ClaimsQueueItem>(
  // ...existing pagination, keys, controller...
  columns: _defaultColumnsForSection(context, l10n, section),
  columnChoices: _allColumnsForSection(context, l10n, section),
  columnVisibilityTitle: l10n.commonTableSettingsTitle,
  search: AppListTableSearch<ClaimsQueueItem>(
    // matcher, standardized filter/settings labels (see Search chrome)
  ),
  mobileItemBuilder: (context, item) => _MobileQueueItem(
    item: item,
    section: section,
    state: state,
    // pass ref/context for next-action button
  ),
);
```

Pass `ref` into `_ClaimsQueuePanel` if needed for next-action buttons (convert to `ConsumerWidget` if not already — it already is).

### 4. Standardize l10n

In `frontend/lib/l10n/app_en.arb` only:

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"claimsNextActionColumnLabel": "Next action"
```

Run codegen: `cd frontend && flutter gen-l10n`.

Update `advancedFilterTitle` / `columnVisibilityTitle` to use shared keys. `claimsFiltersLabel` may remain for backward compatibility but prefer shared keys in table chrome.

### 5. Update tests

File: `frontend/test/features/claims/presentation/claims_workspace_page_test.dart`

- Authorizations tab: expect ≤5 default `DataTable` headers; **no** `Invoice` column; expect `Next action` header.
- Active claims tab: expect `Invoice` only via Settings (hidden by default) — test may need to open Table Settings or check `findsNothing` for Invoice in default view (already partially tested).
- Settled tab: expect `Settlement amount` visible; no next-action button for `CLM-PAID`.
- Add matcher/visibility tests if feasible (follow `frontend/test/shared/components/app_list_table_test.dart` patterns).

### 6. Format and analyze

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/claims/
```

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` | `package:hosspi_hms/shared/components/components.dart` | Queue table shell |
| `AppListTableColumn` | same | Column definitions |
| `AppListTableSearch` | same | Search + Filters chrome |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableColumnVisibilityMemory` | `package:hosspi_hms/shared/components/app_list_table_column_visibility_memory.dart` | Used internally when `columnVisibilityStorageKey` set |
| `AppWorkspaceStatusBadge` | `components.dart` | Status column |
| `AppListItemText` | `components.dart` | Optional two-line patient cell |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate next-action writes |
| `appListTableCompareText` / `appListTableCompareDateTime` | `components.dart` | Sort comparators |

Existing detail/dialog code in the same page file — **reuse**, do not duplicate:

- `_openClaimsDetailDialog`
- `_openAuthorizationStatusDialog`
- `_openSubmitClaimDialog`
- `_openClaimResponseDialog`
- `_detailActions`

## Files to Create / Modify / Delete

| File | Action |
|------|--------|
| `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` | **Modify** — columns, search matcher, next-action, mobile, `columnChoices`, l10n wiring |
| `frontend/lib/l10n/app_en.arb` | **Modify** — add shared keys + `claimsNextActionColumnLabel` |
| `frontend/test/features/claims/presentation/claims_workspace_page_test.dart` | **Modify** — update column expectations |
| Optional: `frontend/lib/features/claims/presentation/widgets/claims_workspace_table.dart` | **Create** only if extraction keeps page maintainable |

**Do not modify:** `claims_workspace_controller.dart`, repository/API layers, or Insurance Setup panel unless compile errors force import moves.

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule).
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`.
- Add `claimsNextActionColumnLabel` for the column header.

## Database Migrations

No database migrations required — schema unchanged. Table standardization is Flutter presentation-only.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/claims/
```

Manual smoke (web or device):

1. `/claims` → Authorizations: 5 columns, Filters opens **Advanced filters**, Settings opens **Table Settings**, column visibility persists per tab when switching away and back.
2. Active claims: next-action shows **Record response** for `SUBMITTED`, **Resubmit claim** for `REJECTED`.
3. Row tap opens detail dialog; next-action in row opens the same dialog as detail action panel.
4. Settled: no write next-action; status badge visible.
5. Insurance Setup: still no table.
6. Mutate a claim (in dev) — table refreshes without full page reload.

## Testing Requirements

- [ ] Each table tab: search, Filters, Settings only in chrome (no export/refresh in search bar)
- [ ] Column visibility persists for session per `claims_<section>` key
- [ ] ≤5 default columns; row number automatic
- [ ] Authorizations + Active claims: explicit status + next-action labels per workflow stage
- [ ] Settled: ≤5 columns, status rightmost, no spurious next-action
- [ ] Row tap opens `_openClaimsDetailDialog`
- [ ] Mobile list shows same priority fields + next action when applicable
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `AppAccessActionGate` still gates write actions on next-action column

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the `_ClaimsQueuePanel` queue table on all three queue tabs
- [ ] Domain logic, permissions, deep links, summary bar, and tab toolbar preserved
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/claims/` passes
