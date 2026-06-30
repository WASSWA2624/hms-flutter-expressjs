# HR Staff Onboarding — Employment & Compensation Refinement

## Context

The **Add staff profile** dialog (`showHrStaffOnboardingDialog` in `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart`) is missing usable reference data and a compensation section on create. Position, Department, and Practitioner type dropdowns render empty; Roles and access appears before practitioner-specific fields; compensation is only shown on edit.

## Objective

Refine the onboarding form so Employment, Roles, and Compensation are pre-populated, logically ordered, and persisted end-to-end (backend + frontend).

## Requirements



### 1. Position (searchable select + auto-create)

- Seed a **global hospital position catalog** (e.g. Nurse, Doctor, Pharmacist, Lab Technologist, Radiologist, Receptionist, HR Officer, Administrator, Ward Manager, Theatre Nurse, Billing Clerk, Housekeeper, Biomedical Engineer, Mortuary Attendant, Security Officer, Porter, Dietitian, Physiotherapist, Anaesthetist, Surgeon, Midwife).
- Expose positions via HR reference data (`GET /hr/reference-data` → `staff_positions`) so the Position dropdown is never empty on first open.
- Keep **searchable select** UX; remove or demote the “Add a new position” checkbox in favor of **type-to-create**: if the user enters a label not in the catalog, create `staff_position` on submit (backend upsert) and attach it to the profile.
- Align seed list with `DEFAULT_STAFF_POSITION_NAMES` in `backend/src/modules/hr-workspace/services/hr-workspace.service.js`; expand it to cover common roles worldwide.



### 2. Department (facility-scoped, pre-populated)

- Pre-populate Department from the **facility’s existing departments** (same source as Operations/seed catalog — e.g. Outpatient, Inpatient, Emergency, Laboratory, Radiology, Pharmacy, Billing, Operations, etc.).
- Load via reference data (`departments` in `HrReferenceData`); do not require HR to type department names manually.
- Default scope: current session `facility_id`; show human-friendly labels, persist `department_id`.



### 3. Practitioner type (role-gated, expanded catalog)

- **Reorder sections**: Person → Employment (staff number, position, department, hire date) → **Roles and access** → **Practitioner type** (conditional) → **Compensation** → Consultation fee (conditional).
- Show Practitioner type **only when** selected roles include a clinical prescriber (e.g. `DOCTOR`, `SPECIALIST`). Hide for nurses, admin, lab, etc.
- Expand `PRACTITIONER_TYPE_OPTIONS` beyond `MO` / `SPECIALIST` to globally recognized types, e.g.:
  - Medical Officer (MO)
  - Specialist / Consultant
  - Resident / Registrar
  - Intern / House Officer
  - General Practitioner (GP)
  - Surgeon
  - Anaesthetist
  - Paediatrician
  - Obstetrician/Gynaecologist
- Store canonical codes in backend (`staff-profile.schema.js`, `staff-profile.service.js`); display localized labels in UI (`app_en.arb`).
- Update consultation-fee visibility logic to match the expanded practitioner set.



### 4. Compensation (new section on create)

- Add a **Compensation** `AppFormSection` on **create and edit**, placed after Roles (and Practitioner type when shown).
- Use shared `AppCurrencyAmountField` for rate + currency (not plain `AppTextField`).
- **Pay type** select with flexible models already supported by API:
  - Consultation Fee (`PER_CONSULTATION`)
  - Monthly salary (`PER_MONTH`)
  - Daily wage (`PER_DAY`)
  - Hourly (`PER_HOUR`)
  - Per procedure / per task (`PER_PROCEDURE`)
- Include **Effective from** date; section is optional but fully wired when filled.
- Persist via existing onboarding payload (`compensations` array) and `staff_compensation` table; keep schema in sync (`compensationPayTypeSchema`).



### 5. Backend synchronization

- Ensure `ensureOnboardingReferenceData` / `listReferenceData` always returns non-empty positions, departments (for facility), practitioner types, and roles before the dialog opens.
- Seed positions in non-production **and** provide a migration or tenant bootstrap path so production tenants get the catalog on first HR access.
- On onboard/create staff: upsert unknown position names; validate practitioner type against expanded enum; create compensation row when provided.
- Add/adjust backend tests for reference-data seeding, position auto-create, and compensation on create.



### 6. Frontend quality

- Follow `frontend/.cursor/design-system.mdc` and existing `AppFormSection` / `AppResponsiveFieldRow` patterns.
- All new strings in `app_en.arb`.
- Update `hr_staff_onboarding_dialog_test.dart` for: populated dropdowns, role-gated practitioner type, compensation on create, position auto-create.



## Acceptance criteria

- [ ] Position, Department, and Practitioner type dropdowns show options on first open (screenshots no longer empty).
- [ ] User can pick or type a new position; it is created and saved without a separate checkbox flow.
- [ ] Practitioner type appears only after relevant roles are selected.
- [ ] Compensation section visible on create with `AppCurrencyAmountField` and all four pay types.
- [ ] Create staff persists position, department, practitioner type, roles, and compensation in one submit.
- [ ] `flutter analyze` and targeted `flutter test` / backend tests pass.



## Key files


| Layer             | Path                                                                             |
| ----------------- | -------------------------------------------------------------------------------- |
| Dialog UI         | `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart`  |
| Reference data    | `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart` |
| Amount field      | `frontend/lib/shared/components/app_currency_amount_field.dart`                  |
| HR reference API  | `backend/src/modules/hr-workspace/services/hr-workspace.service.js`              |
| Staff onboard API | `backend/src/modules/staff-profile/services/staff-profile.service.js`            |
| Schemas           | `backend/src/modules/staff-profile/schemas/staff-profile.schema.js`              |


