# Add Staff Profile Dialog — Refinement Prompt

## Objective

Polish the **Add staff profile** dialog (`showHrStaffOnboardingDialog` in `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart`) so onboarding is focused, visually structured, data-complete, and consistent across platforms. Wire any missing backend support so create-staff works end-to-end.

**Companion context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md), [prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md)

---

## Scope

| In scope | Out of scope |
| -------- | ------------ |
| Add-staff dialog UI/UX, validation, reference data, responsive layout | Edit-staff flows unless required for parity |
| Staff number generation API (if missing) | Full compensation/payroll module |
| Reusable role-assignment component for HR and other modules | Permission matrix editing (stays in Access Admin) |
| Seed/reference data for positions and practitioner types | Link-existing-user onboarding path |

---

## Requirements

### 1. Simplify person & access (create-only)

- **Remove** the “Create new user” / “Link existing user” segmented control from **Add staff**. This dialog always creates a new user account with the staff profile.
- Retain “link existing user” only where a separate edit/link flow already exists outside this dialog (if any).
- **Required:** first name, last name, email, phone.
- **Optional:** address, temporary password (omit or clearly mark optional; do not block submit when empty).
- Use **staff** terminology in all labels and copy (not mixed user/staff wording).

### 2. Section layout & responsiveness

- Treat each block as a distinct **section** with consistent visual treatment (`AppFormSection` or design-system equivalent): heading, spacing, subtle container/divider.
  - Person and access
  - Employment
  - Roles and access *(create only)*
  - Compensation *(conditional — see §5)*
- On **large / maximized** dialog width (≥ ~900px): render fields in a **two-column** grid within each section (e.g. first name + last name, email + phone).
- On narrow viewports: single column. Test web, tablet, and mobile.

### 3. Employment fields & reference data

| Field | Behavior |
| ----- | -------- |
| **Staff number** | Toggle or action: **Generate** (system-assigned, tenant-scoped format) **or** manual entry. Show generated value; allow override before submit. |
| **Position** | Searchable dropdown populated from **predefined hospital positions** (clinical + administrative). Seed common roles (e.g. Nurse, Doctor, Pharmacist, Radiologist, Lab Technologist, Receptionist, HR Officer, Administrator). Keep “Add new position” as an escape hatch, not the default. |
| **Department** | Fetch from existing tenant departments (`referenceData.departments` / API). |
| **Practitioner type** | Pre-filled enum/options from backend reference data. |
| **Hire date** | Default **today**; user may change (past or future start dates). |

Ensure backend reference endpoint returns positions, departments, and practitioner types; add seed data if lists are empty in dev.

### 4. Roles and access — reusable component

Replace the current checkbox list + “Select all roles” / “Clear roles” pattern with a **shared role-assignment widget** usable in HR onboarding and anywhere roles are assigned in the app.

Component should support:

- Search/filter roles
- Add one or more roles; remove individual roles
- Per-role summary (name, permission count, system-critical badge)
- **Effective permissions** read-only preview (aggregated from selected roles)
- Empty state with the existing warning: *no roles → limited access*

Do **not** duplicate Access Admin’s full permission matrix editor. Link or deep-link to Access Admin only when full role CRUD is needed.

Extract from or align with `hr_access_dialogs.dart` where possible.

### 5. Compensation section

- **Hide** the compensation block on add-staff unless the tenant/workflow requires it at onboarding.
- If shown: expand only when the user opts in (not a bare “Compensation” checkbox with no context).
- Prefer deferring compensation to the existing **Update compensation** dialog on staff detail when onboarding does not need it.
- Remove dead UI if compensation at onboarding is not a product requirement.

### 6. Backend & integration

- `onboardStaff` payload must reflect validation rules above (required phone, optional password, staff number mode).
- Auto-generate staff number server-side when requested; enforce uniqueness per tenant.
- Assign selected roles during onboarding (`user_role`); return created staff + user in one mutation where supported.
- Subscribe to HR realtime events so the staff table refreshes after create.

### 7. Quality & consistency

- All strings in `app_en.arb`.
- Follow `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`, `layouts.mdc`.
- Run `flutter analyze` and add/update widget tests for: section layout breakpoints, required-field validation, staff-number generate vs manual, role picker, hire-date default.

---

## Acceptance criteria

1. Add staff dialog has no create/link user toggle; all person fields match required/optional rules.
2. Maximized dialog shows two-column field grids; narrow screens stay single-column.
3. Sections are visually distinct and labeled consistently.
4. Position, department, and practitioner type dropdowns are populated from API/seed data.
5. Staff number can be generated or entered manually.
6. Hire date defaults to today and is editable.
7. Role assignment uses the new reusable component with effective-permissions preview.
8. Compensation is absent or clearly optional per product decision—not a confusing empty checkbox.
9. Create staff succeeds on frontend + backend with tests passing.
