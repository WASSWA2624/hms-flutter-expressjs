# Add Staff Profile Dialog — UI Fixes

**Target:** `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` (and shared HR access widgets as needed).

**Context:** The Add staff profile modal is nearly complete. Fix layout, employment/staff-number UX, and wire reference data so dropdowns and role assignment work against the current facility.

---

## 1. Staff details layout

- Place **Address** and **Temporary password** on the **same row** in a two-column layout (match the grid used for first name / last name / email / phone).
- Keep the temporary-password helper text: *"Leave blank to auto-generate a secure password."*

---



## 2. Employment — staff number mode

Replace the current segmented **Generate / Enter manually** control with **two radio buttons/fields**:


| Option    | Label (i18n)                        | Behavior                                    |
| --------- | ----------------------------------- | ------------------------------------------- |
| Default   | Automatically generate staff number | **Hide** the staff number field entirely    |
| Alternate | Enter staff number manually         | **Show** a required staff number text field |


- Default selection: **Automatically generate**.
- Do not show an empty placeholder container when Automatically generate is selected.

---



## 3. Employment — reference data

Populate dropdowns from **facility-scoped** reference data (demo seed already defines these):

- **Position** — list available positions; keep **Add a new position** checkbox + inline field.
- **Department** — list departments for the **current facility** only (not tenant-wide or empty).
- **Practitioner type** — populate options.
- **Hire date** — keep defaulting to today; no change required.

If `referenceData` is empty on open, ensure the HR workspace controller loads positions, departments, and practitioner types for the active `facilityId` before rendering the form.

---



## 4. Roles and access

The Roles and access section is non-functional: roles are missing and add-role controls do not work.

**Expected behavior:**

- Load and display assignable roles for the tenant/facility.
- Allow adding roles via searchable multi-select (search → pick role → chip/list of selected roles),
- Show selected roles with remove affordance.
- **Effective permissions** panel updates live from selected roles (existing preview logic).
- Retain the warning when no roles are assigned: *"No roles assigned yet. This staff member will have limited access until roles are assigned."*

---



## Acceptance criteria

- [ ] Address + temporary password share one two-column row on wide layouts.
- [ ] Staff number uses radio buttons; field visible only in manual mode.
- [ ] Position, department, and practitioner type dropdowns show facility-scoped options from demo/reference data.
- [ ] Roles can be searched, added, removed; effective permissions preview works.
- [ ] All new strings in `app_en.arb`; `flutter analyze` and `hr_staff_onboarding_dialog_test.dart` pass.