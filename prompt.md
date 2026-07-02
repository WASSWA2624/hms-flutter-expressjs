# Refine patient admission request flow

## Context

From **Patient Registry → patient detail → Quick actions**, staff initiate an inpatient admission **request** for the selected patient. The dialog already exists (`ClinicalAdmissionActionDialog`, opened via `_PatientAdmissionQuickDialog` in `patient_registry_page.dart`). Refine it — do not rebuild from scratch.

**Primary files**
- `frontend/lib/features/patients/presentation/widgets/patient_detail_quick_actions.dart`
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` (`_PatientAdmissionQuickDialog`)
- `frontend/lib/shared/clinical_actions/dialogs/clinical_admission_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart`
- `frontend/lib/l10n/app_en.arb` / `app_fr.arb`

## Requirements

### 1. Copy & intent

- Rename the quick-action label from **“Admit patient”** to **“Request admission”** (or equivalent l10n). The action requests admission; it does not complete admission.
- Dialog title and submit label should align: **“Request admission”** (reuse `clinicalRequestAdmissionAction` where appropriate).

### 2. Dialog chrome

- Open the admission request dialog **maximized by default** (`AppDialog.initialMaximized: true`).
- **Remove the Cancel footer button.** The header close (×) is the only dismiss action.
- Add a **leading icon** to the primary **Request admission** submit button (e.g. bed/hospital icon, consistent with dialog header).

### 3. Facility-aware workflow

- **Single-facility users:** hide the Facility field; pre-select the user’s facility behind the scenes and pass it on submit.
- **Multi-facility users:** show **Facility (optional)** in a **Workflow** section (as in screenshots).
- **Cascading location fields:** Facility → Ward → Room → Bed.
- When any parent selection changes, **reset all dependent child fields** (changing facility must also clear ward, room, and bed).

### 4. Location selection UX

- Ward, Room, and Bed are **required**.
- Show a **live selection summary** (Ward / Room / Bed info tiles) that updates as each dropdown is filled — not only after the final bed is chosen.
- Preserve existing empty-state messaging when no rooms/beds are available for the current selection.

### 5. Clinical fields

- **Admission reason** — required.
- **Notes** — optional.

### 6. Submit behaviour & routing

On successful submit, the admission request must:

1. Create/route the request to the **target ward/department** implied by the selected location (ICU, general ward, etc.).
2. **Notify the responsible admission staff** for that ward/department (or the configured admission receiver), using existing notification/realtime patterns in the codebase.
3. Keep the current end-to-end flow intact (OPD disposition → IPD admission → bed assignment) unless a dedicated admission-request API is clearly the better fit — prefer minimal, correct changes.

Show success/error feedback via existing `AppFailure` / snackbar patterns. Close the dialog on success and refresh patient detail.

## Acceptance criteria

- [ ] Quick action reads “Request admission”; dialog title matches.
- [ ] Dialog opens maximized; no Cancel button; submit has an icon.
- [ ] Single-facility users never see Facility; multi-facility users do.
- [ ] Changing facility, ward, or room resets downstream selections.
- [ ] Summary tiles reflect ward → room → bed progressively.
- [ ] Submit blocked without reason; notes optional.
- [ ] Request reaches the correct ward/department queue and triggers staff notification.
- [ ] Existing/widget tests updated; `flutter test` passes for touched areas.

## Out of scope

- Redesigning unrelated patient-detail sections (encounters, identifiers, other quick actions).
- New backend endpoints unless the current submit path cannot satisfy routing/notification.
