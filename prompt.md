# Refactor the Reception Workspace to a Table-Based Layout

## Objective

Replace the card-based worklist in the Reception workspace (`/reception`) with a data-table layout using the shared `AppListTable` component. Each tab (Appointments, Desk queue, Active visits, Payment gate) should render its data in `AppListTable` with one attribute per column, and row taps should open a modal dialog showing patient details and contextual actions.

---

## Current State

**File:** `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`

The page currently renders (top-to-bottom):

1. **`Row` with `AppTabStrip` + "Register patient" `AppButton.primary`** — four tabs driven by `ReceptionDeskSection` enum (`appointments`, `queue`, `activeVisits`, `paymentGate`). "Register patient" is access-gated via `receptionFrontDeskWriteRequirement`.
2. **Standalone `AppSearchBar`** — search field with debounce (250 ms, local filter via `_matchesSearch`). Three trailing actions: Refresh, Schedule appointment, Start OPD encounter.
3. **List of `_ReceptionDeskCard` widgets** — one Material card per `_ReceptionDeskRow`. Each card embeds:
   - `AppPatientDetails` (name, display ID, date/time, status badge).
   - `AppWorkflowStepper` (5-step OPD workflow for flow rows).
   - `ReceptionBillingGuidancePanel` (billing hints for flow/queue rows).
   - `AppPermissionActionList` (contextual action buttons per row type).
4. **`_ReceptionDeskRow`** — a union-type holding exactly one of: `OpdAppointment`, `OpdQueueEntry`, or `OpdFlowSummary`.

**Supporting files:**

| File | Purpose |
|---|---|
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionWorkspaceQuery` (deep-link/filter) and `ReceptionDeskSection` enum |
| `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart` | Helpers: `openReceptionScheduleAppointment`, `openReceptionPatientEditor`, `openReceptionInsuranceCapture` |
| `frontend/lib/features/reception/presentation/widgets/reception_billing_guidance.dart` | `ReceptionBillingGuidancePanel` widget |
| `frontend/lib/features/reception/presentation/reception_access.dart` | Access requirements: `receptionFrontDeskWriteRequirement`, `receptionWorkspaceRequirement`, `receptionInsuranceCaptureRequirement` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>`, `AppListTableColumn<T>`, `AppListTableSearch<T>`, `AppListTableColumnVisibilityController<T>` |
| `frontend/lib/shared/components/app_search_bar.dart` | `AppSearchBar`, `AppSearchBarAction`, `AppSearchBarFilterGroup`, `AppSearchBarFilterValue` |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` / `AppTabItem` |
| `frontend/lib/shared/components/app_patient_details.dart` | `AppPatientDetails` (compact patient identity + optional expanded fields) |
| `frontend/lib/shared/components/app_patient_detail_dialog.dart` | `AppPatientDetailDialog` (reusable scrollable dialog shell wrapping `AppDialog`) |
| `frontend/lib/shared/patient_actions/patient_detail_dialog.dart` | Patient detail dialog helpers |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` layout wrapper |

---

## Target Design

### 1. Keep the existing tab row + "Register patient" button

- The existing `Row` with `AppTabStrip` + `AppButton.primary("Register patient")` is correct. No changes needed.
- Tabs remain routable via `ReceptionWorkspaceQuery.section` / `?section=` query parameter.

### 2. Remove the standalone `AppSearchBar`

- Delete the standalone `AppSearchBar` widget below the tab row.
- All search/filter/action functionality moves into `AppListTable`'s built-in `search` parameter (see step 4).

### 3. Replace `_ReceptionDeskCard` list with `AppListTable<_ReceptionDeskRow>`

- Remove the `for` loop that renders `_ReceptionDeskCard` widgets.
- Replace with a single `AppListTable<_ReceptionDeskRow>` that renders directly below the tab row (no `AppContentPanel` wrapper).
- Provide `items: rows` (the already-filtered `List<_ReceptionDeskRow>` from `_buildRows`).

### 4. Use `AppListTable`'s built-in search via `AppListTableSearch`

Configure the `search` parameter on `AppListTable` with an `AppListTableSearch<_ReceptionDeskRow>(...)`:

- `controller`: the existing `_searchController`.
- `semanticLabel` / `hintText`: `l10n.receptionSearchHint`.
- `matcher`: a function matching against patient name, display ID, and patient ID (replace the current `_matchesSearch`).
- `isLoading`: wired to `isRefreshing`.
- `trailingActions`: move the Refresh, Schedule appointment, and Start OPD encounter actions here. Also add the column visibility `settingsAction` from `AppListTableColumnVisibilityController`.
- Remove the standalone Refresh button; wire refresh through a trailing action inside the table's search bar.

### 5. Define table columns — one attribute per column

Each `AppListTableColumn<_ReceptionDeskRow>` must display exactly one attribute (no combined/composite cells). Define columns per tab section:

**Appointments tab:**

| Column | Source |
|---|---|
| Patient name | `row.appointment.patientDisplayName` |
| Appointment ID | `row.appointment.publicId` |
| Scheduled date/time | `row.appointment.scheduledStart` (formatted) |
| Status | `row.appointment.status` (use `opdStageDisplayLabel`) |

**Desk queue tab:**

| Column | Source |
|---|---|
| Patient name | `row.queueEntry.patientDisplayName` |
| Queue ID | `row.queueEntry.publicId` |
| Queued at | `row.queueEntry.queuedAt` (formatted) |
| Priority | `row.queueEntry.priority` (if available) |
| Status | `row.queueEntry.status` |

**Active visits tab:**

| Column | Source |
|---|---|
| Patient name | `row.flow.patientDisplayName` |
| Encounter ID | `row.flow.publicId` |
| Started at | `row.flow.startedAt` (formatted) |
| Current step | `row.flow.stage` (use `opdStageDisplayLabel`) |
| Assigned doctor | `row.flow.assignedDoctorName` (if available) |

**Payment gate tab:**

| Column | Source |
|---|---|
| Patient name | `row.flow.patientDisplayName` |
| Encounter ID | `row.flow.publicId` |
| Stage | `row.flow.stage` (use `opdStageDisplayLabel`) |
| Amount / billing status | billing info from `ReceptionBillingGuidancePanel` source (if available) |

Use `columnChoices` for optional columns and `AppListTableColumnVisibilityController` with a `columnVisibilityStorageKey` so users can show/hide columns and the preference persists.

### 6. Provide a `mobileItemBuilder` for responsive list mode

`AppListTable` requires a `mobileItemBuilder`. Build a compact list-tile representation of each `_ReceptionDeskRow` showing patient name, display ID, status, and date/time. Reuse `AppPatientDetails` in compact mode (with `initiallyExpanded: false`, `showAvatar: false`) if appropriate, or build a simpler `ListTile`.

### 7. Handle row tap — open a modal dialog with patient details + actions

Wire `onRowSelected` on `AppListTable` to open a modal dialog when a row is tapped.

**Dialog structure:**

- Use the existing `AppPatientDetailDialog` shell (scrollable, maximizable).
- Inside the dialog content:
  1. **`AppPatientDetails`** — show full patient identity (name, display ID, date/time, status badge), expanded by default.
  2. **`AppWorkflowStepper`** — for flow rows, show the 5-step OPD progress (reuse existing `_receptionWorkflowSteps` logic).
  3. **`ReceptionBillingGuidancePanel`** — for flow/queue rows, show billing hints.
  4. **`AppPermissionActionList`** — show the same contextual action buttons currently rendered on each card (appointment actions, check-in, start from queue, prioritize, assign doctor, edit patient, schedule appointment, capture insurance). Reuse the existing `_actions` logic from `_ReceptionDeskCard`.

This consolidates the card's content into a dialog, keeping the same actions and workflow visibility but behind a row-tap interaction.

### 8. Workflow progress visibility for the receptionist

- In the table, the "Current step" / "Status" column should display the patient's current workflow stage using `opdStageDisplayLabel`, giving the receptionist a quick at-a-glance view.
- In the row-tap dialog, the full `AppWorkflowStepper` shows detailed progress through all 5 OPD steps.
- This ensures the receptionist always knows which step each patient is at without opening the dialog.

### 9. Tab counts (badges)

- Display the row count for each tab as a badge or suffix on the `AppTabItem` label (e.g., "Appointments (3)", "Active visits (12)") so the receptionist sees volume at a glance.

---

## Resulting Widget Tree (Target)

```
ResponsivePage (maxWidth: dataHeavy)
  └── Column
        ├── Row (tabs + register patient action)
        │     ├── Expanded(AppTabStrip [Appointments, Desk queue, Active visits, Payment gate])
        │     └── AppButton.primary("Register patient")
        └── AppListTable<_ReceptionDeskRow>
              ├── Built-in search bar (search field + Refresh + Schedule apt + Start OPD + Column settings)
              ├── Column headers (one attribute per column, per section)
              └── Data rows → onRowSelected → modal dialog:
                    └── AppPatientDetailDialog
                          ├── AppPatientDetails (expanded)
                          ├── AppWorkflowStepper (flow rows)
                          ├── ReceptionBillingGuidancePanel (flow/queue rows)
                          └── AppPermissionActionList (contextual actions)
```

---

## Files to Modify

| File | Change |
|---|---|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Remove standalone `AppSearchBar`, remove `_ReceptionDeskCard` list and widget. Replace with `AppListTable<_ReceptionDeskRow>` using `AppListTableSearch`, column definitions per section, `onRowSelected` opening a dialog. Refactor `_ReceptionDeskCard._actions` logic into a standalone function callable from the dialog. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | No changes expected (entities and `ReceptionDeskSection` remain as-is). |

---

## Technical Constraints

- **State management**: continue using `opdWorkspaceControllerProvider` (Riverpod). Tab switching, search, refresh, and all OPD actions must still work via the existing controller.
- **URL-driven state**: the `section` query parameter must still reflect the selected tab. Deep-linking to `/reception?section=queue&search=wilson` must select the correct tab and pre-fill the search.
- **Local search**: search remains client-side with 250 ms debounce. Wire through `AppListTableSearch.matcher` instead of the current `_matchesSearch`.
- **One attribute per column**: no composite cells combining multiple data fields. Each column renders exactly one field.
- **Responsiveness**: `AppListTable` handles adaptive display via `displayMode: AppListTableDisplayMode.adaptive` — table on desktop, list tiles on mobile. Provide both `columns` and `mobileItemBuilder`.
- **Column persistence**: use `columnVisibilityStorageKey` and optionally `columnWidthStorageKey` so the user's column preferences persist across sessions.
- **No regressions**: all existing actions (register patient, schedule appointment, start OPD encounter, check-in, prioritize, assign doctor, edit patient, capture insurance, appointment actions, flow actions) must continue to function identically, now triggered from the row-tap dialog instead of inline card buttons.
- **Reuse existing components**: `AppPatientDetails`, `AppPatientDetailDialog`, `AppWorkflowStepper`, `ReceptionBillingGuidancePanel`, `AppPermissionActionList`, `AppListTable`, `AppTabStrip` are all already defined. Do not duplicate them.
- **Accessibility**: table must be keyboard-navigable. Row selection via Enter/Space. Dialog must trap focus and be dismissible via Escape.
- **Performance**: the reception screen is the most frequently used screen. Minimize rebuilds. Use `keepPreviousDataDuringRefresh: true` (already set). Avoid unnecessary widget allocations in cell builders.
- **Clean up**: remove the `_ReceptionDeskCard` widget class entirely after migration. Remove any dead code, unused imports, or orphaned methods.
