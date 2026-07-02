# Register New Patient — Global Dialog Prompt

## Objective

Introduce a single, reusable **Register new patient** dialog for first-time patient master-record creation across HOSSPI HMS. On the **Patient registry** screen, replace the **Emergency registration** toolbar action with **Register patient** and open this dialog. Registration must create the patient record only — no OPD encounter, IPD admission, emergency queue, or other downstream workflow.

**Source of truth:**

1. [`.cursor/app-write-up.mdc`](.cursor/app-write-up.mdc) — one patient master record per person; registry owns demographics, not clinical queues
2. [`.cursor/flows/opd-flow.mdc`](.cursor/flows/opd-flow.mdc) §2 — search existing patient first; register only when no match
3. [prompts/08-patients-module-prompt.md](prompts/08-patients-module-prompt.md) — modal-first registry patterns

---

## Current state

| Area | Location | Notes |
| ---- | -------- | ----- |
| Registry primary action | `patient_registry_page.dart` | **Add patient** → `PatientFormDialog` (full form, duplicate check) |
| Registry secondary action | `patient_registry_page.dart` | **Emergency registration** → `EmergencyPatientFormDialog` (minimal fields) |
| Dialog implementations | `patient_registry_page.dart` (~7k lines) | `PatientFormDialog`, `EmergencyPatientFormDialog` are page-local, not shared |
| OPD intake | `shared/components/opd_encounter_dialog.dart` | Embeds its own inline new-patient fields inside **Start OPD encounter** |
| Dialog shell | `shared/components/app_dialog.dart` | Supports `initialMaximized`, resize, maximize/minimize |

**Problem:** three overlapping registration UIs; emergency registration is a separate minimal path; no global component for “register patient only.”

---

## Scoped work

### 1. Patient registry toolbar

| Change | Detail |
| ------ | ------ |
| Remove | Secondary **Emergency registration** button (`patientsEmergencyRegisterAction`) |
| Add / consolidate | One **Register patient** entry point with an appropriate icon (e.g. `Icons.person_add_alt_1_outlined`) |
| Avoid duplication | Do not leave both **Add patient** and **Register patient** if they open the same flow — keep a single registration action on the registry toolbar |

### 2. Global shared component

Extract and define **`RegisterNewPatientDialog`** (name may vary) under `frontend/lib/shared/` (e.g. `shared/components/` or `shared/patient_actions/`), exported from the shared barrel.

| Requirement | Detail |
| ----------- | ------ |
| Title | **Register new patient** (new i18n key, e.g. `patientsRegisterNewPatientTitle`) |
| Shell | `AppDialog` with `initialMaximized: true`, `resizable: true`, `showMaximizeButton: true` — same interaction model as large workspace dialogs (e.g. **Start OPD encounter**) |
| Form | Reuse existing shared form primitives: `AppFormShell`, `AppTextField`, `PatientPhoneField`, `AppGenderField`, `AppDateField`, `AppResponsiveFieldRow`, etc. |
| Behaviour | Create-only (`POST /patients`); duplicate lookup before save (reuse `PatientFormDialog` logic); no edit mode in this component |
| API wiring | Caller supplies `onSubmit` / `onLookupDuplicates` / `referenceData` via constructor callbacks — dialog stays presentation-only |
| Scope | **Registration only** — on success, return the created `Patient` (or `true`); do not start OPD, emergency, or IPD flows from inside the dialog |

**Suggested fields (minimum viable registration):**

- First name, last name (required)
- Phone, email (optional where backend allows)
- Date of birth, gender (optional but supported)
- Primary identifier type/value (optional)
- Facility (when reference data requires it)
- Notes (optional)

Do **not** include emergency-only copy (“complete after urgent care”) or OPD routing/billing sections.

### 3. Adoption (reuse everywhere)

Replace page-local and inline first-time registration UIs with the shared dialog:

| Call site | Action |
| --------- | ------ |
| `patient_registry_page.dart` | Open `RegisterNewPatientDialog` from toolbar; remove `EmergencyPatientFormDialog` usage |
| `opd_encounter_dialog.dart` | When mode = new patient, open or embed the same shared form — do not maintain a second field set |
| Other modules | Grep for `createPatient`, `EmergencyPatientFormDialog`, `PatientFormDialog` (create path), and inline registration forms; migrate to the shared dialog |

Keep **`PatientFormDialog`** (or equivalent) for **editing** existing patients only, or refactor edit into a separate shared component if needed — out of scope for create-only registration.

### 4. i18n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale-development rule)
- New labels: toolbar action, dialog title, body/helper (if any), submit action (e.g. `patientsRegisterNewPatientAction`)
- Retire or repurpose unused emergency-registration toolbar strings only if no other screen uses them

---

## Out of scope

- Starting OPD, emergency, or IPD workflows after registration
- Full patient chart / documents / consent / merge workflows
- Backend schema changes (use existing patient create API)
- Removing **Edit patient** flows

---

## Acceptance criteria

- [ ] Patient registry shows **Register patient** (not **Emergency registration**); one clear registration entry point
- [ ] Clicking opens **Register new patient** in a maximized-by-default, resizable `AppDialog`
- [ ] Submitting creates a patient master record only; no automatic encounter or queue handoff
- [ ] `RegisterNewPatientDialog` lives in `frontend/lib/shared/` and is imported by registry and OPD (at minimum)
- [ ] Duplicate-candidate warning still blocks unsafe duplicate saves
- [ ] All user-visible strings use i18n keys in `app_en.arb`
- [ ] `flutter analyze` and patient registry / shared dialog tests pass

---

## Implementation pointers

| Area | Location |
| ---- | -------- |
| Registry toolbar & wiring | `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` |
| Existing full create form (extract from) | `PatientFormDialog` in same file |
| Existing minimal emergency form (remove) | `EmergencyPatientFormDialog` in same file |
| OPD inline registration | `frontend/lib/shared/components/opd_encounter_dialog.dart` |
| Dialog shell | `frontend/lib/shared/components/app_dialog.dart` |
| Patient create API | `patient_registry_controller.dart` → `createPatient` |
| Tests | `frontend/test/features/patients/presentation/patient_registry_page_test.dart` |

---

## Quality gate

From `frontend/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/patients/
```
