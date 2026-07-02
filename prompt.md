# Patient details after registration

## Goal

After a patient is successfully registered, open the **patient details dialog** for the newly created patient instead of only closing the registration dialog and returning to the list. This lets staff review the record and take follow-up actions immediately.

## Requirements

### 1. Post-registration flow

- On successful save in `RegisterNewPatientDialog`, close the registration dialog and open the patient details dialog for the **new patient ID**.
- Apply this wherever patient registration is used (e.g. patient registry, OPD walk-in intake).
- Keep the existing success snackbar/feedback where appropriate.

### 2. Maximized by default

- The patient details dialog must open **maximized by default** (`AppDialog.initialMaximized: true`).
- Apply this default **everywhere** the patient details dialog is shown, not only after registration.

### 3. Reusable shared component

- Extract or consolidate patient details into a **globally reusable** shared component (build on `AppPatientDetailDialog` / `AppDialog` where possible).
- Replace inline or duplicated implementations (e.g. `_PatientDetailDialog` in `patient_registry_page.dart`, nursing workspace usage) with the shared component.
- Expose a single entry point (e.g. `showPatientDetailDialog(context, ref, patientId)`) for all call sites.

## Implementation notes

- `createPatient` already returns the created `Patient`; propagate the new patient ID through the registration dialog callback instead of only returning `true`.
- Reuse existing detail-loading logic (`selectPatient`, skeleton states, actions) from the registry page where practical.
- Update affected widget tests (registration flow, detail dialog open state, maximized default).

## Acceptance criteria

- [ ] Successful registration opens the new patient’s details dialog automatically.
- [ ] Details dialog opens maximized on every entry point.
- [ ] One shared component/helper is used for all patient detail displays.
- [ ] Existing tests pass; new or updated tests cover the post-registration and maximized-default behavior.
