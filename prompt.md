# HR Staff Onboarding Dialog — UI Refinement

## Objective

Polish the **Add staff profile** dialog (`showHrStaffOnboardingDialog`) so it reuses shared form components, uses space efficiently, and simplifies role assignment — without changing onboarding behavior or API payloads.

## Target

| Item | Location |
|------|----------|
| Primary form | `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` |
| Role picker (shared) | `frontend/lib/shared/components/app_role_assignment_picker.dart` |
| Tests | `frontend/test/features/hr/presentation/widgets/hr_staff_onboarding_dialog_test.dart`, `frontend/test/shared/components/app_role_assignment_picker_test.dart` |

Follow `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`, and existing HR dialog conventions. Keep all user-visible strings in `app_en.arb`.

---

## Requirements

### 1. Reuse shared input components

Replace raw `AppTextField` usages with the established shared wrappers where they exist:

| Field | Use |
|-------|-----|
| Staff email | `AppEmailField` (validation via `l10n.authEmailInvalidMessage`; required message via `l10n.validationRequired` or existing HR l10n) |
| Staff phone | `AppPhoneField` (country/number labels from `l10n.appPhone*`) |
| Temporary password | `AppTextField` with `obscureText: true` and `enableObscureTextToggle: true` — match auth/register pattern |
| First / last name | Keep `AppTextField` (no dedicated wrapper) |
| Address | Keep `AppTextField` with `maxLines: 2` and word capitalization — consistent with facility address fields |

Do **not** change field labels, required flags, helper text, or `toPayload()` keys.

### 2. Staff number mode — horizontal layout

The **Automatically generate staff number** / **Enter staff number manually** radio options currently stack vertically and waste space.

- Render both options **on one row** in two columns when the dialog is wide (use `AppResponsiveFieldRow.two` at the existing `_kOnboardingTwoColumnBreakpoint`).
- Stack vertically only on narrow viewports.
- Manual staff-number text field behavior stays unchanged (shown only when manual mode is selected).

### 3. Roles and access — remove empty-state warning

Remove the red warning row:

> *No roles assigned yet. This staff member will have limited access until roles are assigned.*

- Do not show this indicator in `AppRoleAssignmentPicker` for staff onboarding (remove from the picker default or pass a flag / `emptyWarning: null` from the onboarding form).
- Keep **Effective permissions** preview and the *No roles selected yet* empty-selection hint unless product says otherwise.

### 4. Roles and access — single searchable select

Replace the separate **Search roles** text field and **Add role** dropdown with **one searchable multi-select flow**:

- One `AppSelectField<String>.searchable` (or equivalent shared pattern) where the user can type to filter roles and pick to add.
- Selected roles still appear as removable chips/tiles below; effective-permissions preview unchanged.
- Preserve role sort order from reference data and exclude already-selected roles from the dropdown.
- On wide layouts, role picker controls may sit in one row; do not reintroduce a standalone search field.

Refactor inside `AppRoleAssignmentPicker` so other consumers benefit; avoid HR-only duplication.

---

## Acceptance criteria

- [ ] Email and phone use `AppEmailField` / `AppPhoneField` with correct validation and l10n.
- [ ] Password field supports show/hide toggle like auth forms.
- [ ] Staff-number radios appear side-by-side on wide dialogs.
- [ ] Empty-state roles warning is gone; permissions preview still works when roles are selected.
- [ ] Role assignment uses a single searchable select (no separate search bar).
- [ ] `flutter analyze` and targeted widget tests pass.
- [ ] No regression in create-staff payload or edit-staff behavior.

## Test updates

- Remove/update assertions expecting the removed warning text.
- Add layout assertion for horizontal staff-number radios at wide width (if feasible in widget tests).
- Verify role can be searched and added via the consolidated select.
