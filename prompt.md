# Simplify Reception Search Actions and Reuse Patient Detail Dialog

## Objective

Streamline the Reception workspace (`/reception`) search bar so it only exposes filter and column-settings controls, and replace the custom row-detail dialog with the same Patient Registry patient detail dialog used on `/patients`. Contextual workflow actions (schedule appointment, start/update OPD encounter, etc.) must live in that reused dialog—not in the table search bar.

---

## Current State (from screenshots + code)

**File:** `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`

### What works
- Tab strip with counts: Appointments, Desk queue, Active visits, Payment gate
- `AppListTable<_ReceptionDeskRow>` with one-attribute columns and row selection
- "+ Register patient" primary action on the tab row

### Problems visible in screenshots

1. **Search bar is overcrowded** — trailing actions currently include:
   - Refresh
   - Schedule appointment
   - Start OPD encounter
   - Column settings
   - Overflow **"More actions"** menu (`maxTrailingActions: 3`)
2. **Custom row dialog is wrong UX** — `_ReceptionRowDetailDialog` (built on `AppPatientDetailDialog`) shows a sparse action strip and large blank white space. It does **not** match Patient Registry.
3. **Patient Registry is the reference** — on `/patients`, row tap opens `PatientDetailDialog` via `showPatientDetailDialog(...)`. That dialog already includes patient header, active work, quick actions (schedule appointment, start/update encounter, etc.), and related sections. Reception must reuse this exact dialog.

---

## Target Design

### 1. Slim the `AppListTable` search bar

In `AppListTableSearch<_ReceptionDeskRow>`:

**Remove these trailing actions:**
- Refresh
- Schedule appointment
- Start OPD encounter

**Keep only:**
- Built-in filter controls (advanced filter / filter button from `AppSearchBar` / `AppListTableSearch`)
- Column settings action from `AppListTableColumnVisibilityController.settingsAction(context)`

**Also remove:**
- The overflow **"More actions"** menu caused by excess trailing actions — with only settings remaining, set `maxTrailingActions` high enough that settings never collapses into overflow, or omit `maxTrailingActions` if defaults already avoid overflow for a single action.

**Keep on the page (outside search bar):**
- Tab strip + "+ Register patient" button (unchanged)

### 2. Replace `_ReceptionRowDetailDialog` with Patient Registry dialog

On row tap (`onRowSelected`):

1. Resolve the row’s **patient ID** (`row.patientId`).
2. If missing, show a localized failure/snackbar and return.
3. Open the shared Patient Registry dialog:

```dart
await showPatientDetailDialog(context, ref, patientId);
// or equivalently:
await openReceptionPatientEditor(context, ref, patientId);
```

**Requirements:**
- The dialog must look and behave **exactly** like Patient Registry (`/patients` row click).
- Reuse `showPatientDetailDialog` / `PatientDetailDialog` from:
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog_body.dart`
  - re-exported via `frontend/lib/shared/patient_actions/patient_detail_dialog.dart`
- Do **not** invent a reception-specific detail shell.
- Schedule appointment, start OPD encounter, update encounter, and other clinical/quick actions must come from that dialog’s existing `PatientDetailQuickActions` / active-work panels—not from reception search-bar buttons.

### 3. Delete the custom reception detail dialog

Remove entirely:
- `_ReceptionRowDetailDialog` class
- `_openRowDetail` custom dialog wiring that builds reception-only actions
- Any now-unused reception-only dialog action callbacks used solely by that dialog

Keep reception-specific table row actions only if still needed elsewhere; otherwise delete dead paths.

### 4. Preserve reception table behavior

Do not regress:
- Tab filtering / section counts
- Local search matcher
- Column definitions (one attribute per column)
- Column visibility persistence keys
- Empty state (`AppStateView`)
- Deep-link `ReceptionWorkspaceQuery` / `?section=` support

---

## Resulting Widget Tree (Target)

```
ResponsivePage
  └── Column
        ├── Row
        │     ├── Expanded(AppTabStrip [...counts...])
        │     └── AppButton.primary("Register patient")
        └── AppListTable<_ReceptionDeskRow>
              ├── Search bar
              │     ├── Search field
              │     ├── Filter button
              │     └── Column settings only
              └── Rows → onRowSelected → showPatientDetailDialog(patientId)
                    └── PatientDetailDialog (same as /patients)
                          ├── PatientDetailHeader
                          ├── PatientDetailActiveWorkPanel
                          ├── PatientDetailQuickActions
                          │     (schedule appointment, start/update encounter, …)
                          └── Related patient sections
```

---

## Files to Modify

| File | Change |
|---|---|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Strip search trailing actions to column settings only; on row tap call `showPatientDetailDialog` / `openReceptionPatientEditor`; delete `_ReceptionRowDetailDialog` and related dead code. |
| `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart` | Prefer reusing `openReceptionPatientEditor` (already wraps `showPatientDetailDialog`). No new dialog. |

No new shared components. No duplicate patient detail UI.

---

## Technical Constraints

- **Reuse, don’t fork:** Patient detail UX must be identical to Patient Registry.
- **Row identity:** Open dialog with the patient `human_friendly_id` / patient id from the row (`row.patientId`). Never invent a reception-only detail model.
- **RBAC:** Keep existing access gating; PatientDetailDialog already enforces patient write/delete and clinical action permissions.
- **Localization:** No hard-coded English for new strings; reuse existing l10n keys.
- **Cleanup:** Remove unused imports/methods after deleting the custom dialog and search actions.
- **UX:** Search bar must not show Refresh / Schedule appointment / Start OPD / More actions.
