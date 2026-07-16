# Standardize Reception Tables

## Objective

Refactor every `AppListTable` on the Reception workspace (`/reception`, `ReceptionWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, tab toolbar actions (Schedule appointment, Register patient, Refresh, navigation shortcuts), deep-link routing, or unrelated screen chrome unless required for compilation.

## Current State (from audit)

### Screen architecture

| Field | Value |
|-------|-------|
| Route | `/reception` |
| Page widget | `ReceptionWorkspacePage` |
| Content state | `_ReceptionWorkspaceContentState` |
| Primary file | `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` |
| Data provider | `opdWorkspaceControllerProvider` (`frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`) — realtime via `listenForRealtimeRefresh` + `WorkspaceEventRefreshProfile.clinicalFlow` |
| Row entity | `_ReceptionDeskRow` (union of `OpdAppointment`, `OpdQueueEntry`, `OpdFlowSummary`) |
| Tabs (`ReceptionDeskSection`) | `appointments`, `queue`, `activeVisits`, `paymentGate` |
| Deep link | `?section=<value>` via `ReceptionWorkspaceQuery` / `receptionDeskSectionFromQuery` |

There is **one** `AppListTable<_ReceptionDeskRow>` instance in `_ReceptionWorkspaceContentState.build()` (lines ~246–294). Column definitions switch per tab via `_columnsForSection(l10n)`. Per-tab storage keys already exist: `reception_${_section.name}` and `reception_cw_${_section.name}`.

### Table inventory and gaps

| Tab | Entity backing | Default columns today | Count | Gaps vs `prompt.md` |
|-----|----------------|----------------------|-------|---------------------|
| **Appointments** | `OpdAppointment` via `_ReceptionDeskRow.appointment` | `patient_name`, `appointment_id`, `scheduled_time`, `status` | 4 | Missing `next_action`; `patient_name` plain `Text` (no MRN subtitle); `appointment_id` mislabeled with `opdPatientIdLabel`; search matcher omits scheduled time, status, appointment id; no `columnChoices` |
| **Queue** | `OpdQueueEntry` via `_ReceptionDeskRow.queue` | `patient_name`, `queue_id`, `queued_at`, `payment_status`, `status` | 5 | Missing `next_action`; `queue_id` mislabeled with `opdPatientIdLabel`; `payment_status` raw text (should be badge or hidden choice); search matcher incomplete |
| **Active visits** | `OpdFlowSummary` via `_ReceptionDeskRow.flow` | `patient_name`, `patient_id`, `started_at`, `current_step`, `assigned_doctor`, `next_action` | **6** | **Exceeds 5-column budget**; status column id is `current_step` not `status`; `assigned_doctor` should be `columnChoices`; mobile missing `WorkflowActionButton` |
| **Payment gate** | `OpdFlowSummary` via `_ReceptionDeskRow.flow` | `patient_name`, `patient_id`, `stage`, `consultation_fee`, `payment_status`, `next_action` | **6** | **Exceeds 5-column budget**; two status-like columns (`stage` + `payment_status`); `consultation_fee` should be `columnChoices`; mobile missing next action |

### Search chrome gaps (all tabs)

Current wiring in `AppListTableSearch` (~lines 260–287):

| Requirement | Current | Gap |
|-------------|---------|-----|
| Filters button label | `l10n.receptionFiltersLabel` → `"Filters"` | OK |
| Advanced filters modal title | `advancedFilterTitle: l10n.receptionFiltersLabel` → `"Filters"` | Must be **Advanced filters** |
| Settings button | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` | OK |
| Table Settings modal title | `columnVisibilityTitle` **not set** | Must set to **Table Settings** |
| Search matcher | `_searchMatcher` — only `patientName`, `patientId`, `displayId` | Must include all column + `columnChoices` fields per tab |
| `columnChoices` | Not wired | Missing — hidden columns not searchable/toggleable |
| Extra search chrome actions | None | OK (refresh lives in tab toolbar — preserve that) |

### Row interaction gaps

| Row kind | Current `onRowSelected` | Required |
|----------|------------------------|----------|
| Appointment | `openReceptionPatientEditor` → `showPatientDetailDialog` | Open `showOpdAppointmentActionsDialog` (`frontend/lib/shared/opd_actions/opd_appointment_actions_dialog.dart`) with `workspaceState: widget.state` |
| Queue | Same patient editor | Open contextual queue/encounter dialog — mirror OPD `_OpdPatientActionsDialog` pattern or `showOpdAppointmentActionsDialog` when `appointmentId` is set; otherwise patient detail with front-desk actions |
| Flow (active visits / payment gate) | Same patient editor | Open `FlowActionsDialog` (`frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`) — already used in `_openFlowActions` for `flowId` deep links (~line 974) |

Next-action column handlers must open the **same** destination as row tap (dialog), not generic module home.

### Responsiveness gaps

- `displayMode` not set explicitly — default is `AppListTableDisplayMode.adaptive` (OK); set explicitly for clarity.
- `_mobileItemBuilder` (~lines 829–849) uses `AppPatientDetails` with name, id, time, status only — missing `WorkflowActionButton` for flow rows, payment/billing badge for payment gate, and appointment/queue-specific next actions.

### Realtime (preserve)

- `ReceptionWorkspacePage` watches `opdWorkspaceControllerProvider`.
- Loading flags: `isRefreshingAppointments`, `isRefreshingQueue`, `isRefreshingFlows`.
- Do not bypass provider state or mutate table rows directly.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters/Settings chrome, `columnChoices`, `mobileItemBuilder`)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` + `WorkflowActionButton`
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` — `_OpdWorkspaceTable` (per-section columns, `columnChoices`, comprehensive search matcher, `_NextStepCell`, `_OpdTableMobileRow`)
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey | columnWidthStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|------------------------|
| `AppListTable<_ReceptionDeskRow>` | Appointments | `_ReceptionDeskRow` (appointment) | patient, scheduled_time, status, next_action | `reception_appointments` | `reception_cw_appointments` |
| Same instance | Desk queue | `_ReceptionDeskRow` (queue) | patient, queued_at, status, next_action | `reception_queue` | `reception_cw_queue` |
| Same instance | Active visits | `_ReceptionDeskRow` (flow) | patient, started_at, status, next_action | `reception_activeVisits` | `reception_cw_activeVisits` |
| Same instance | Payment gate | `_ReceptionDeskRow` (flow) | patient, consultation_fee, status, next_action | `reception_paymentGate` | `reception_cw_paymentGate` |

Wire `columnChoices` to a superset of all tab-specific optional columns (see per-tab plans below). Reuse the existing per-section storage key pattern.

### Column plan — Appointments tab

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|----------------|--------------|-------|
| 1 | `patient` | `l10n.opdPatientNameLabel` | `appointment.patientDisplayName` + `appointment.patientIdentifier` | `AppListItemText` primary + MRN subtitle |
| 2 | `scheduled_time` | `l10n.receptionScheduledTimeLabel` | `appointment.scheduledStart` | `AppFormatters.dateTime` |
| 3 | *(reserved — only 3 data slots when workflow applies)* | — | — | — |
| 4 | `status` | `l10n.receptionStatusLabel` | `appointment.status` | `AppWorkspaceStatusBadge` + `opdStageDisplayLabel` |
| 5 | `next_action` | Contextual verb | status-driven | Button opening `showOpdAppointmentActionsDialog`; label e.g. Check in / Add to queue / Reschedule per `OpdAppointmentActionsDialog` logic — never `opdNextActionFilterLabel` |

**`columnChoices` (hidden by default):** `appointment_id` (`appointment.publicId ?? appointment.id`, label: new `receptionAppointmentIdLabel`), `provider` (`appointment.providerDisplayName`, label: `l10n.opdProviderColumnLabel` or existing OPD key), `reason` (`appointment.reason`).

### Column plan — Queue tab

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `patient` | `l10n.opdPatientNameLabel` | `queueEntry.patientDisplayName` + `queueEntry.patientIdentifier` | `AppListItemText` |
| 2 | `queued_at` | `l10n.receptionQueuedAtLabel` | `queueEntry.queuedAt` | formatted datetime |
| 3 | *(unused slot)* | — | — | — |
| 4 | `status` | `l10n.receptionStatusLabel` | `queueEntry.status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | Contextual verb | status-driven | Opens queue/encounter dialog; use `WorkflowActionButton` with `queueEntryId: entry.publicId ?? entry.id` when resolvable, else compact button mirroring primary queue action |

**`columnChoices`:** `queue_id`, `payment_status` (use `opdQueueBillingStatusLabel` + badge via `opdQueueBillingState`), `provider` (`queueEntry.providerDisplayName`), `reason` (`queueEntry.appointmentReason`).

### Column plan — Active visits tab

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `patient` | `l10n.opdPatientNameLabel` | `flow.patientDisplayName` + `flow.patientIdentifier` | `AppListItemText` |
| 2 | `started_at` | `l10n.receptionStartedAtLabel` | `flow.startedAt` | formatted datetime |
| 3 | *(unused)* | — | — | — |
| 4 | `status` | `l10n.receptionCurrentStepLabel` | `flow.stage` | `AppWorkspaceStatusBadge` + `opdStageDisplayLabel` + `opdStageStatusTone` |
| 5 | `next_action` | `l10n.opdNextActionFilterLabel` (column header only) | `flow.nextStep` / `flow.displayNextStep` | Existing `WorkflowActionButton` pattern (~lines 725–732); `compact: true` |

**`columnChoices`:** `patient_id`, `assigned_doctor` (`flow.assignedStaffDisplayName`).

### Column plan — Payment gate tab

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `patient` | `l10n.opdPatientNameLabel` | `flow.patientDisplayName` + `flow.patientIdentifier` | `AppListItemText` |
| 2 | `consultation_fee` | `l10n.receptionConsultationFeeLabel` | `flow.consultationFee` + `flow.consultationCurrency` | Keep as priority data for cashier triage |
| 3 | *(unused)* | — | — | — |
| 4 | `status` | `l10n.receptionPaymentStatusLabel` | billing state | `opdFlowBillingDisplay(context, flow)` → `AppWorkspaceStatusBadge` (consolidate `stage` + `payment_status` into this single status column) |
| 5 | `next_action` | explicit payment action | `flow.nextStep` | `WorkflowActionButton` with `sourceModule: 'reception'` if needed; must deep-link to billing/payment capture, not generic billing home |

**`columnChoices`:** `patient_id`, `stage` (`flow.stage` badge), `payment_detail` (raw payment fields if needed).

### Search chrome (all tabs)

Update `AppListTableSearch` in `reception_workspace_page.dart`:

```dart
advancedFilterButtonLabel: l10n.receptionFiltersLabel, // "Filters"
advancedFilterTitle: l10n.commonAdvancedFiltersTitle, // "Advanced filters"
// ...
columnVisibilityLabel: l10n.commonTableSettingsActionLabel, // "Settings"
columnVisibilityTitle: l10n.commonTableSettingsTitle, // "Table Settings"
```

Replace `_searchMatcher` with a tab-aware matcher (or `_ReceptionDeskRow.matchesSearch(section, query)`) that lowercases and checks **every** default + `columnChoices` field for the active tab — including formatted datetimes, status labels (`opdStageDisplayLabel`), billing labels, provider names, and next-step display text.

Add `columnChoices` to `AppListTable` (mirror OPD `columnChoices: [...]` pattern at `opd_workspace_page.dart` ~2199).

### Row interaction

Implement `_openRowDetail(BuildContext context, _ReceptionDeskRow row)`:

```dart
Future<void> _openRowDetail(_ReceptionDeskRow row) async {
  if (row.appointment != null) {
    final bool? changed = await showOpdAppointmentActionsDialog(
      context: context,
      appointment: row.appointment!,
      workspaceState: widget.state,
    );
    // snackbar on changed == true (mirror _openFlowActions)
    return;
  }
  if (row.queueEntry != null) {
    // Open queue-appropriate dialog (reuse OPD/shared dialogs; do not navigate away)
    return;
  }
  if (row.flow != null) {
    await _openFlowActions(row.flow!);
    return;
  }
}
```

Wire `onRowSelected: (row) => unawaited(_openRowDetail(row))`.

Next-action column buttons must call the same handlers (stop propagation via `WorkflowActionButton` built-in behavior).

### Mobile builder

Replace `_mobileItemBuilder` with tab-aware layout (extract `_ReceptionDeskMobileRow` widget):

- Patient: `AppListItemText` or `AppListItemRow` with name + identifier
- Subtitle: tab time field (scheduled / queued / started)
- Status badge (same as desktop column 4)
- Trailing: `WorkflowActionButton` or compact next-action control (same handler as desktop column 5)
- Pattern reference: `_OpdTableMobileRow` and `_MortuaryMobileListItem`

Set `displayMode: AppListTableDisplayMode.adaptive` explicitly on `AppListTable`.

## Implementation Steps

1. **l10n** — `frontend/lib/l10n/app_en.arb`
   - Add `commonAdvancedFiltersTitle`: `"Advanced filters"`
   - Add `commonTableSettingsTitle`: `"Table Settings"`
   - Add `receptionAppointmentIdLabel`: `"Appointment ID"`
   - Add `receptionQueueIdLabel`: `"Queue ID"`
   - Run codegen (`flutter gen-l10n` or project equivalent) if not auto-run by analyze

2. **Refactor column builders** — `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
   - Extract `_receptionDefaultColumns(ReceptionDeskSection, AppLocalizations)` returning ≤5 columns
   - Extract `_receptionColumnChoices(...)` returning full superset per tab
   - Use `AppListItemText` for patient column across all tabs
   - Rename mislabeled id columns; move demoted columns to `columnChoices`
   - Add `next_action` column to appointments and queue tabs
   - Reduce active visits to 5 columns; reduce payment gate to 5 columns

3. **Search chrome**
   - Set `columnVisibilityTitle`, fix `advancedFilterTitle`
   - Implement comprehensive tab-aware `_searchMatcher`
   - Pass `columnChoices` to `AppListTable`

4. **Row interaction**
   - Replace `_openPatientDetail` with `_openRowDetail` (entity-aware dialogs above)
   - Align next-action column `onPressed` / `WorkflowActionButton` with same destinations

5. **Mobile**
   - Implement `_ReceptionDeskMobileRow` with status + next-action parity
   - Wire as `mobileItemBuilder`

6. **Preserve**
   - Tab strip, counts, deep links (`_applyDeepLink`, `_updateUrlForSection`)
   - `receptionFrontDeskWriteRequirement` gates on toolbar actions
   - `opdWorkspaceControllerProvider` refresh paths
   - Terminal status filtering (`_isTerminalStatus`, `_paymentGateStages`, `_activeVisitStages`)

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Patient two-line cells |
| `AppWorkspaceStatusBadge` | `components.dart` | Status columns |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Flow next-action columns |
| `showOpdAppointmentActionsDialog` | `package:hosspi_hms/shared/opd_actions/opd_actions.dart` | Appointment row detail + next action |
| `FlowActionsDialog` | `package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart` | Flow row detail |
| `openReceptionPatientEditor` | `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart` | Fallback patient detail from dialogs |
| `opdStageDisplayLabel` / `opdStageStatusTone` | `package:hosspi_hms/shared/opd_actions/opd_status_display.dart` | Status formatting |
| `opdFlowBillingDisplay` / `opdQueueBillingStatusLabel` | `package:hosspi_hms/shared/opd_actions/opd_billing_state.dart` | Payment gate / queue payment badges |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify (generated) | `frontend/lib/l10n/app_localizations.dart`, `app_localizations_en.dart` — via codegen |
| Create (optional) | `frontend/test/features/reception/presentation/reception_workspace_table_test.dart` — widget tests for column count, search matcher, row handler routing |
| Delete | None |

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule)
- Prefer shared keys: `commonTableSettingsActionLabel`, new `commonTableSettingsTitle`, new `commonAdvancedFiltersTitle`
- Keep `receptionFiltersLabel` as the Filters **button** label; use `commonAdvancedFiltersTitle` for the **modal title**

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/reception/
```

Manual smoke (web or device):

1. Open `/reception` — each tab renders ≤5 data columns (+ auto row number)
2. Search matches hidden column values (toggle via Settings, then search)
3. Filters opens **Advanced filters** modal; Settings opens **Table Settings** modal
4. Column visibility persists when switching tabs and back (per `reception_<section>` key)
5. Row tap on appointment → appointment actions dialog; flow row → `FlowActionsDialog`
6. Next-action button matches row-tap behavior
7. Narrow viewport: mobile cards show status + action
8. Trigger OPD realtime event or refresh — table updates without full page reload

## Testing Requirements

- [ ] Each tab: search, Filters, Settings only in table chrome (refresh stays in tab toolbar)
- [ ] Column visibility persists for session per `reception_<section>` key
- [ ] ≤5 default columns per tab; row number automatic
- [ ] Workflow tabs (queue, active visits, payment gate): explicit status + next-action labels
- [ ] Appointments tab: status + contextual next-action (not generic "Next action" filter label as button text)
- [ ] Row tap opens correct entity dialog (not always patient registry)
- [ ] Mobile list shows same priority fields, status, and next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `receptionFrontDeskWriteRequirement` still gates write actions in dialogs/toolbar

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the Reception desk table on all four tabs
- [ ] Domain logic preserved (filtering, terminal statuses, deep links, permissions)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/reception/` passes
- [ ] No new table/search/filter implementations — only `AppListTable` shared stack
