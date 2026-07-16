# Standardize Physiotherapy Tables

## Objective

Refactor every `AppListTable` on the Physiotherapy workspace (`/physiotherapy`, `PhysiotherapyWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

---

## Current State (from audit)

### Screen overview

| Field | Value |
|-------|-------|
| Route | `/physiotherapy` |
| Page widget | `PhysiotherapyWorkspacePage` |
| Primary file | `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart` |
| Entity | `TherapyWorkItem` (`typedef` for `PhysiotherapyWorkItem`) |
| Provider | `physiotherapyWorkspaceControllerProvider` (`PhysiotherapyWorkspaceController`) |
| Realtime | `listenForRealtimeRefresh` with `RealtimeEventGroups.physiotherapy` in controller `build()` |

**Note:** The generator stub listed tabs "All, Scheduled, In progress, Completed" — that is **incorrect**. The live screen uses six `PhysiotherapyQueueScope` tabs via `AppTabStrip`: **Referrals**, **Today**, **Active plans**, **Follow-up due**, **Missed**, **Completed**. Deep-link query param is `?section=<value>` (e.g. `referrals`, `today`, `active-plans`, `follow-up`, `missed`, `completed`), not `?status=`.

### Table inventory (single table instance)

| # | Widget / builder | File | Entity | Tab binding |
|---|------------------|------|--------|-------------|
| 1 | `_PhysiotherapyWorkspace._buildWorklist` → `AppListTable<TherapyWorkItem>` | `physiotherapy_workspace_page.dart` | `TherapyWorkItem` | Same table widget; `section` state + `state.query.scope` filter rows per tab |

There is **one** `AppListTable` on this screen. Tab switches change `PhysiotherapyQueueScope`, URL `section` query param, toolbar primary action, and storage keys — not separate table widgets.

### Current default columns (`_columns`, 5 — at budget)

| Position | Column id | Label key | Source field(s) | Cell pattern |
|----------|-----------|-----------|-----------------|--------------|
| 1 | `patient` | `physiotherapyPatientColumnLabel` | `displayTitle` / `displaySubtitle` | `AppListItemText` (two-line, one field) ✓ |
| 2 | `source` | `physiotherapySourceColumnLabel` | `source` + `sourceTitle`/`referralReason` | `AppListItemText` (type + context subtitle) ✓ |
| 3 | `session` | `physiotherapySessionColumnLabel` | `sessionAt` | `Text` via `_formatDateTime` |
| 4 | `status` | `physiotherapyStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` via `_workspaceStatusForStatus` ✓ |
| 5 | `next` | `physiotherapyNextActionColumnLabel` | `status` → `_nextActionLabel` | **Plain `Text`** — **gap: not interactive** |

### Hidden `columnChoices` (`_optionalColumns`, 4)

| Column id | Label key | Field |
|-----------|-----------|-------|
| `plan` | `physiotherapyPlanColumnLabel` | `plan` |
| `attendance` | `physiotherapyAttendanceColumnLabel` | `attendanceStatus` |
| `billing` | `physiotherapyBillingColumnLabel` | `billingStatus` |
| `therapist` | `physiotherapyTherapistColumnLabel` | `therapistName` |

### Search chrome (current)

| Aspect | Current wiring | Gap vs `prompt.md` |
|--------|----------------|---------------------|
| Search widget | `AppListTableSearch<TherapyWorkItem>` in `_buildWorklist` | — |
| Matcher | `item.matchesSearch(query, field: state.query.filters.searchField)` | Default branch in `matchesSearch` already includes hidden fields (`plan`, `therapist`, etc.) ✓; keep and verify after changes |
| Filters button | `showAdvancedFilterButton: true`, label `physiotherapyFiltersLabel` ("Filters") | ✓ label |
| Filters modal title | `advancedFilterTitle: l10n.physiotherapyFiltersLabel` ("Filters") | **Must be "Advanced filters"** |
| Settings button | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` ("Settings") | ✓ |
| Settings modal title | `columnVisibilityTitle: l10n.physiotherapyTableColumnsTitle` ("Therapy table columns") | **Must be "Table Settings"** |
| Extra search chrome actions | None (refresh is correctly in `AppTabStrip.secondaryActions`) | ✓ |
| Column persistence | `AppListTableColumnVisibilityController` + `columnVisibilityStorageKey: 'physiotherapy_${section.name}'` + `columnWidthStorageKey: 'physiotherapy_cw_${section.name}'` | ✓ per-tab keys |

### Row interaction (current)

| Aspect | Current | Gap |
|--------|---------|-----|
| `onRowSelected` | Calls `_openTherapyDetailDialog` → `controller.selectWorkItem` + `showAppDialog` with `_buildDetail` | ✓ |
| Detail actions | `_ActionsPanel` with full workflow actions | ✓ |
| Next-action column | Static `Text(_nextActionLabel(...))` | **Must become clickable control opening same dialogs as detail actions** |

### Responsiveness (current)

| Aspect | Current | Gap |
|--------|---------|-----|
| `displayMode` | Not set (defaults to `AppListTableDisplayMode.adaptive`) | ✓ |
| `mobileItemBuilder` | `_TherapyWorklistMobileItem` — title, subtitle, status badge only | **Missing source, session, next-action button** |

### Workflow status → next-action labels (`_nextActionLabel`)

| Status | Label (l10n key) | Target dialog / action |
|--------|------------------|------------------------|
| `REFERRAL` | `physiotherapyAcceptReferralAction` | Accept referral (`ClinicalFreeTextActionDialog` → `controller.acceptReferral`) |
| `ACCEPTED` | `physiotherapyRecordAssessmentAction` | `_AssessmentDialog` → `controller.recordAssessment` |
| `ASSESSMENT` | `physiotherapyScheduleSessionAction` | `_ScheduleSessionDialog` → `controller.scheduleSession` |
| `TODAY` | `physiotherapyRecordSessionAction` | `_SessionDialog` → `controller.recordSession` |
| `IN_TREATMENT` | `physiotherapyRecordSessionAction` | `_SessionDialog` → `controller.recordSession` |
| `ACTIVE_PLAN` | `physiotherapyScheduleFollowUpAction` | `ClinicalFollowUpActionDialog` → `controller.scheduleFollowUp` |
| `FOLLOW_UP_DUE` | `physiotherapyScheduleFollowUpAction` | `ClinicalFollowUpActionDialog` → `controller.scheduleFollowUp` |
| `MISSED` | `physiotherapyMarkAttendanceAction` | `_AttendanceDialog` → `controller.markAttendance` |
| `COMPLETED` | `physiotherapyPrintInstructionsAction` | `_printInstructions` |
| default | `physiotherapyAcceptReferralAction` | Accept referral |

`WorkflowActionRegistry` has only inbound routing action `PHYSIOTHERAPY_SESSION` (deep-link to module). **Do not** use `WorkflowActionButton` for internal physiotherapy row actions — implement a module-local `_TherapyNextActionButton` (see Target Architecture).

### Per-tab table matrix

All six tabs share identical column definitions (`_columns` / `_optionalColumns`). Differences per tab:

| Tab (`PhysiotherapyQueueScope`) | URL `section` | Storage key suffix | Toolbar primary action |
|---------------------------------|---------------|--------------------|------------------------|
| `referrals` | `referrals` (default) | `referrals` | Schedule session |
| `today` | `today` | `today` | Record session |
| `activePlans` | `active-plans` | `activePlans` | Schedule session |
| `followUpDue` | `follow-up` | `followUpDue` | Schedule follow-up |
| `missed` | `missed` | `missed` | Mark attendance |
| `completed` | `completed` | `completed` | Print instructions |

Column visibility/width preferences are already isolated per tab via storage keys.

---

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`, `AppListTableColumnVisibilityMemory`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters/Settings search chrome, `columnVisibilityStorageKey`, `onRowSelected` → detail dialog
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()`, `WorkflowActionButton` (pattern for **clickable** next-action cell; adapt for physiotherapy dialogs)
- `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart` — `mobileItemBuilder` with status + next-action parity
- `prompt.md`

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `_buildWorklist` `AppListTable` | All 6 `PhysiotherapyQueueScope` tabs | `TherapyWorkItem` | patient, source, session, status, next_action | `physiotherapy_${section.name}` |
| (same) | (same) | (same) | columnWidthStorageKey | `physiotherapy_cw_${section.name}` |

### Column plan (per table — rename `next` → `next_action`)

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `patient` | `physiotherapyPatientColumnLabel` | `displayTitle` / `displaySubtitle` | Keep `AppListItemText`; `alwaysVisible: true` |
| 2 | `source` | `physiotherapySourceColumnLabel` | `source` + subtitle | Keep `AppListItemText` |
| 3 | `session` | `physiotherapySessionColumnLabel` | `sessionAt` | Sort via `appListTableCompareDateTime` |
| 4 | `status` | `physiotherapyStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge`; `alwaysVisible: true` |
| 5 | `next_action` | `physiotherapyNextActionColumnLabel` | status-derived action | **`_TherapyNextActionButton`** (see below) |

Hidden in `columnChoices` (unchanged ids): `plan`, `attendance`, `billing`, `therapist`.

### `_TherapyNextActionButton` (new widget — required)

Create in `frontend/lib/features/physiotherapy/presentation/widgets/physiotherapy_workspace_widgets.dart` (new file) or as a private widget at the bottom of `physiotherapy_workspace_page.dart`:

```dart
class TherapyNextActionButton extends ConsumerWidget {
  const TherapyNextActionButton({
    required this.item,
    this.compact = true,
    super.key,
  });

  final TherapyWorkItem item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Resolve label via existing _nextActionLabel(l10n, item.status)
    // 2. Resolve icon matching status (reuse icons from _workspaceStatusForStatus or action icons from _ActionsPanel)
    // 3. Gate with AppAccessActionGate(_therapyWriteRequirement) except print (read)
    // 4. Render compact AppButton.secondary or TextButton with explicit label (NOT generic "Action")
    // 5. onPressed: await controller.selectWorkItem(item) then invoke the SAME dialog
    //    handlers used in _ActionsPanel / tab toolbar (_openScheduleSession, _openRecordSession, etc.)
    // 6. Wrap with GestureDetector that stops propagation so row tap does not fire
  }
}
```

Wire the next-action column `cellBuilder` to `TherapyNextActionButton(item: item)`.

Map each status to the existing private dialog helpers already in `physiotherapy_workspace_page.dart` — **extract shared action runners** (e.g. `_runTherapyNextAction(BuildContext, WidgetRef, TherapyWorkItem)`) so `_ActionsPanel`, tab toolbar, and table column share one code path.

### Search chrome (per table)

Update `AppListTableSearch` in `_buildWorklist`:

```dart
advancedFilterButtonLabel: l10n.commonFiltersActionLabel,       // add key if missing, value "Filters"
advancedFilterTitle: l10n.commonAdvancedFiltersTitle,           // add key, value "Advanced filters"
// keep existing filterGroups, textFilters, onFilterChanged wiring

columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle,            // add key, value "Table Settings"
```

Keep `physiotherapyApplyFiltersAction` / `physiotherapyClearFiltersAction` for apply/reset inside the filters modal unless shared keys exist.

Matcher must continue searching hidden `columnChoices` fields. Extend `TherapyWorkItem.matchesSearch` default branch if any optional column field is missing.

### Row interaction

- Keep `onRowSelected` → `_openTherapyDetailDialog`.
- Next-action button opens the **contextual dialog** for that status (not generic module home).
- Detail dialog `_ActionsPanel` must remain; no duplication of detail UI.

### Mobile parity

Replace `_TherapyWorklistMobileItem` with a layout matching desktop priority:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    AppListItemText(title: item.displayTitle, subtitle: item.displaySubtitle),
    // source line (single line)
    // session line
    Row(children: [
      AppWorkspaceStatusBadge(...),
      Spacer(),
      TherapyNextActionButton(item: item, compact: true),
    ]),
  ],
)
```

Pass `ref` via `Consumer` wrapper if needed.

---

## Implementation Steps

### 1. Add shared l10n keys — `frontend/lib/l10n/app_en.arb`

Add (English only per locale rule):

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run code generation if the project requires it after arb edits.

### 2. Extract therapy action runner — `physiotherapy_workspace_page.dart`

- Extract `_runTherapyNextAction(BuildContext context, WidgetRef ref, TherapyWorkItem item)` that:
  1. Calls `physiotherapyWorkspaceControllerProvider.notifier.selectWorkItem(item)` (handle `AppFailure` like `_openTherapyDetailDialog`).
  2. Switches on `item.status.toUpperCase()` and opens the correct existing dialog (`_ScheduleSessionDialog`, `_SessionDialog`, `_AttendanceDialog`, `ClinicalFollowUpActionDialog`, `ClinicalFreeTextActionDialog`, `_AssessmentDialog`, or `_printInstructions`).
  3. Respects the same enable guards as `_ActionsPanel` (e.g. `apiPatientId != null` for schedule session, `hasAppointment` for mark attendance, `isSaving` disables).

### 3. Create `_TherapyNextActionButton` — new widgets file

- File: `frontend/lib/features/physiotherapy/presentation/widgets/physiotherapy_workspace_widgets.dart`
- Export from a barrel only if the feature already uses one; otherwise import directly in the page.
- Use `MouseRegion` + `Semantics` with the explicit action label.
- Stop tap propagation (pattern from `WorkflowActionButton` in `frontend/lib/shared/workflow_actions/workflow_action_button.dart`).

### 4. Update table columns — `physiotherapy_workspace_page.dart`

In `_columns`:
- Rename column id `next` → `next_action`.
- Replace `Text(_nextActionLabel(...))` with `TherapyNextActionButton(item: item)`.
- Add `sortComparator` on next-action label text (like emergency).
- Mark `patient`, `status`, `next_action` with `alwaysVisible: true` if supported.

### 5. Standardize search chrome titles — `physiotherapy_workspace_page.dart`

In `_buildWorklist` `AppListTableSearch`:
- `advancedFilterButtonLabel` → `l10n.commonFiltersActionLabel`
- `advancedFilterTitle` → `l10n.commonAdvancedFiltersTitle`
- On `AppListTable`: `columnVisibilityTitle` → `l10n.commonTableSettingsTitle`

### 6. Upgrade mobile builder — `physiotherapy_workspace_page.dart`

- Refactor `_TherapyWorklistMobileItem` to `ConsumerWidget` or pass `WidgetRef`.
- Surface patient, source, session, status badge, and `TherapyNextActionButton`.

### 7. Verify search coverage — `physiotherapy_entities.dart`

Confirm `PhysiotherapyWorkItem.matchesSearch` default `_` branch includes all `columnChoices` display values (`plan`, formatted `attendanceStatus`, `billingStatus`, `therapistName`). Add formatted labels if raw codes are not user-searchable.

### 8. Update tests — `frontend/test/features/physiotherapy/presentation/physiotherapy_workspace_page_test.dart`

- Assert `search?.advancedFilterTitle` equals `Advanced filters` (via l10n).
- Assert `columnVisibilityTitle` equals `Table Settings`.
- Assert next-action column renders tappable controls (find by action labels like `Accept referral`, `Record session` on seeded items).
- Assert mobile viewport (`Size(390, 844)`) shows next-action control for a seeded `_referralItem`.
- Keep existing tab/storage-key/refresh-toolbar tests passing.

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableColumnVisibilityMemory` | `app_list_table_column_visibility_memory.dart` (via components export) | Backing store |
| `AppWorkspaceStatusBadge` | `components.dart` | Status column |
| `AppListItemText` | `components.dart` | Patient / source cells |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | **Reference only** — do not use for internal therapy steps |
| `ClinicalFreeTextActionDialog` / `ClinicalFollowUpActionDialog` | `package:hosspi_hms/shared/clinical_actions/clinical_actions.dart` | Action dialogs |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission gating |
| `physiotherapyWorkspaceControllerProvider` | `physiotherapy_workspace_controller.dart` | Data + mutations |

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| **Create** | `frontend/lib/features/physiotherapy/presentation/widgets/physiotherapy_workspace_widgets.dart` |
| **Modify** | `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart` |
| **Modify** | `frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart` (search matcher only if needed) |
| **Modify** | `frontend/lib/l10n/app_en.arb` |
| **Modify** | `frontend/test/features/physiotherapy/presentation/physiotherapy_workspace_page_test.dart` |
| **Delete** | None |

---

## l10n

Add/update keys in `frontend/lib/l10n/app_en.arb` only:

| Key | English value |
|-----|---------------|
| `commonFiltersActionLabel` | Filters |
| `commonAdvancedFiltersTitle` | Advanced filters |
| `commonTableSettingsTitle` | Table Settings |

Prefer these shared keys over `physiotherapyFiltersLabel` / `physiotherapyTableColumnsTitle` in table chrome. Keep existing `physiotherapy*` action label keys for next-action button text.

---

## Database Migrations

**No database migrations required — schema unchanged.** Table work is presentation-only.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/physiotherapy/
```

---

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome (refresh stays in tab toolbar)
- [ ] Filters modal title is **Advanced filters**; Settings modal title is **Table Settings**
- [ ] Column visibility persists for session per `physiotherapy_<scope>` key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status badge + clickable next-action with verb labels per status
- [ ] Next-action opens correct dialog (not navigation to `/physiotherapy` home)
- [ ] Row tap opens `_openTherapyDetailDialog` detail modal
- [ ] Mobile list shows patient, source, session, status, and next-action
- [ ] Realtime refresh still updates rows after mutations/events (controller unchanged)
- [ ] Permissions still gate write actions (`_therapyWriteRequirement`)

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the single `AppListTable` on this screen (all six tabs)
- [ ] Domain logic preserved (scopes, filters, dialogs, permissions, deep links, printing)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/physiotherapy/` passes
