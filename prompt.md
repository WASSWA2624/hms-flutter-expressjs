# Start OPD Encounter Dialog — Implementation Prompt

## Objective

Refine `OpdEncounterDialog` into the single, reusable entry point for creating or continuing an OPD encounter across the app (patient registry quick actions, OPD workspace, appointments, and any future caller). The dialog must be **context-aware**, **duplicate-safe**, and **reception-grade** on every screen size and platform.

**Source of truth (read first):**

1. `[.cursor/flows/opd-flow.mdc](.cursor/flows/opd-flow.mdc)` — §2 entry paths, §6 UI rules (one active encounter per patient)
2. `[prompts/12-opd-module-prompt.md](prompts/12-opd-module-prompt.md)` — OPD module standards
3. `[prompts/08-patients-module-prompt.md](prompts/08-patients-module-prompt.md)` — registry quick-action launch pattern

**Central rule:** never create a second active OPD encounter for the same patient. When one exists, surface it clearly and let staff **update or open** that encounter instead of starting a duplicate.

---



## Current implementation (review before changing)


| Area                     | Location                                                                 |
| ------------------------ | ------------------------------------------------------------------------ |
| Shared dialog            | `frontend/lib/shared/components/opd_encounter_dialog.dart`               |
| Patient registry wrapper | `patient_registry_page.dart` → `_PatientOpdEncounterDialog`              |
| OPD workspace entry      | `opd_workspace_page.dart` → `_openOpdEncounterDialog`                    |
| New-patient form reuse   | `RegisterNewPatientForm` via `patient_actions`                           |
| Tests                    | `frontend/test/features/opd/presentation/start_walk_in_dialog_test.dart` |


---



## UX requirements (from design)



### Dialog shell

- Open **maximized by default** (`AppDialog.initialMaximized: true` or equivalent via `showAppDialog` caller).
- Title: **Start OPD encounter**; keep maximize/close controls.
- Responsive layout: mobile (stacked), tablet, and desktop (two-column routing + billing). Support Android, iOS, web, Windows, macOS, Linux.



### Context-aware patient section

The dialog supports three modes — **Existing patient**, **Appointment patient**, **New patient** — but **only show controls for information the caller has not already supplied**.


| Launch context                                                                                  | What to show                                                                                   | What to hide                  |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------- |
| **Generic** (e.g. OPD workspace toolbar)                                                        | Full mode selector + search fields for all three modes                                         | —                             |
| **Known existing patient** (registry quick action, patient detail, deep link with `patient_id`) | Routing + billing only; optional read-only patient chip if helpful                             | Mode tabs, patient search     |
| **Known appointment** (appointment check-in with `appointment_id`)                              | Routing + billing only; pre-fill provider, arrival mode `ONLINE_APPOINTMENT`, billing defaults | Mode tabs, appointment search |
| **New patient only**                                                                            | New-patient fields (`RegisterNewPatientForm`) + routing + billing                              | Existing/appointment search   |


**Principle:** do not ask staff to re-enter data that is already known.

### New-patient flow

- Reuse the existing `RegisterNewPatientForm` (duplicate detection, tenant/facility scope, etc.).
- On successful registration **inside this dialog**, stay in the encounter flow: switch internally to **existing patient** mode with the new `patient_id` and continue to start/update the encounter.
- **Do not** navigate to patient details or registry after registration unless the caller explicitly opts in.



### Active encounter handling (duplicate prevention)

When the selected patient (existing or appointment) has an **open OPD encounter**:

1. Show a full-width **Active OPD encounter found** banner (stretch edge-to-edge within the dialog content — not a narrow inset box).
2. Display encounter context staff need to act without opening another screen:
  - Encounter ID, stage (badge), visit type, assigned staff, payer/billing, arrival time.
3. Change primary action from **Start encounter** → **Open active encounter** — align label with `app_en.arb`.
4. Submit must **update/reuse** the active encounter (`existing_encounter_id` in payload) — never create a duplicate.
5. On success, invoke `onExistingActiveEncounter` so the caller can open the encounter at its **current stage** (OPD workspace row/detail, not a blank form).
6. While resolving active encounter, show a loading state; disable submit until resolution completes or an active encounter is confirmed absent.

For **new patient** mode, skip active-encounter lookup until a patient record exists.

### Form sections (when visible)

**Routing**

- Arrival mode (required for walk-in; hidden or fixed for appointment check-in).
- Search doctor (optional) with helper: *This doctor will handle the patient.*
- Emergency-only fields when arrival mode is `EMERGENCY`.

**Billing**

- Consultation fee + currency (default from provider/facility policy where available).
- Notes (optional).
- Payment required (toggle) and Payment received (checkbox); show payment method + transaction ref when payment received is checked.

---



## API & data contract

- Submit via existing `onSubmit` → `POST /opd-flows/start` or bootstrap payload used today.
- Pass `source` (`patient_registry`, `opd_workspace`, etc.) for analytics/audit.
- Pre-fill from `initialPatient`, `initialPatientId`, `initialAppointment`, `initialAppointmentId`, `defaultArrivalMode`, `defaultProviderId`.
- Active encounter resolution: use `activeFlows` prop when supplied; otherwise query repository for patient's open flows.

---



## Integration checklist

Wire the shared dialog (maximized) from every OPD start entry point:

- [ ] Patient registry — **Start OPD encounter** quick action (`PatientQuickAction.opdCheckIn`)
- [ ] OPD workspace — start encounter action
- [ ] Appointment check-in paths (pre-select appointment mode)
- [ ] Any other `startOpdFlow` / bootstrap callers — replace one-off dialogs with `OpdEncounterDialog`

Each caller implements `onExistingActiveEncounter` to navigate/open the encounter at its current stage.

---



## Acceptance criteria

1. **No duplicate encounters** — selecting a patient with an active encounter never creates a second one; staff see the banner and update/open path.
2. **Context-aware UI** — launching from registry with a known patient shows only routing + billing (+ active banner); no redundant patient picker.
3. **New patient in-flow** — register → continue encounter in the same dialog without redirect to patient details.
4. **Maximized by default** — dialog opens full-screen on desktop/tablet; mobile uses full viewport appropriately.
5. **Full-width active banner** — encounter notice spans the content width; responsive detail grid/wrap on small screens.
6. **Post-submit navigation** — caller opens encounter at current stage so staff are not “blinded” to workflow state.
7. **i18n & theming** — all strings in `app_en.arb`; light/dark/system themes.
8. **Tests** — extend `start_walk_in_dialog_test.dart` for: known-patient hidden picker, active-encounter update path, new-patient register-and-continue, maximized default.

---



## Quality gate

From `frontend/`:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/opd/presentation/start_walk_in_dialog_test.dart
```

