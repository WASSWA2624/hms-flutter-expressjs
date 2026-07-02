# Patient Registration — Tenant/Facility Scope & Form Feedback

## Problem

Registering a patient as a **super admin** (multi-tenant access) fails with **"Tenant is required."** even though the form has no tenant selector. Facility is shown as optional, but backend registration requires scoped `tenant_id` (and `facility_id` where applicable).

## Objective

Fix patient registration so tenant/facility context is resolved correctly for all account types, validation is enforced client-side before submit, and form feedback uses a reusable, color-coded information banner.

---

## 1. Tenant & facility scope on registration forms

Apply to **`RegisterNewPatientForm`** (`frontend/lib/shared/patient_actions/register_new_patient_dialog.dart`) and any other forms that embed it (e.g. OPD intake).

| User context | UI behaviour | Submit payload |
| ------------ | ------------ | -------------- |
| **Single tenant + single facility** (nurses, doctors, paramedics, etc.) | Hide tenant and facility fields. Pre-fill from session (`AppAccessPolicy.tenantId`, `facilityId`). | Include `tenant_id` and `facility_id` silently. |
| **Multi-tenant and/or multi-facility** (super admin, tenant admin) | Show **Tenant** and **Facility** pickers. Both are **required** when visible. | User-selected `tenant_id`; facility list filtered by selected tenant. |

### Implementation notes

- Extend or replace `PatientRegistrationFacilityScope` (`patient_registration_facility_scope.dart`) to cover **tenant** scope as well (e.g. `PatientRegistrationScope`).
- Resolve scope from `AppAccessPolicy` + `PatientReferenceData` (add tenants to reference data if the API does not yet expose them).
- When tenant changes, reset facility selection and reload/filter facilities for that tenant.
- Include `tenant_id` in `buildPayload()` — currently only `facility_id` is sent.
- Mark facility field `isRequired: true` when the picker is shown.

---

## 2. Reusable form information banner

Extract a global **`AppFormInformationBanner`** (or similar) in `frontend/lib/shared/components/` for inline form feedback.

### Layout

- **Horizontal row:** icon on the **left**, title on the **right** (same row).
- Message body below the title row (or as a second line), with appropriate typography.

### Variants (color-coded)

| Variant | Use case | Styling |
| ------- | -------- | ------- |
| **Error** | Validation / submit failures | Error icon + error foreground/background |
| **Warning** | Duplicate patient warning, non-blocking issues | Warning colors |
| **Success** | Confirmation / saved state | Success colors |
| **Info** | Neutral guidance | Info colors |

### Adoption

- Replace `AppFailureStateView` usage **inside forms** (starting with patient registration) with this banner.
- Keep existing `ValidationMessagePresenter` for humanized API field messages; render each message in the variant's message color.
- Title for validation errors: localized `errorValidationTitle` ("Check the details").
- All strings via `app_en.arb`; support light/dark themes.

---

## 3. Client-side validation

Before submit on patient registration:

- Validate all visible required fields (first name, gender, tenant, facility when shown).
- Surface errors via the form information banner **and** inline field validators where applicable.
- Do not call the API until client validation passes.

---

## 4. Register patient dialog actions

In **`RegisterNewPatientDialog`** (`register_new_patient_dialog.dart`):

- **Add a leading icon** to the primary submit button (`AppButton.primary`) — use `Icons.person_add_alt_1_outlined` to match the dialog title icon and the registry page "Register patient" action.
- **Remove the Cancel button** from the dialog footer. Dismissal is already handled by the modal close control in `AppDialog`; a duplicate Cancel action is redundant.

When duplicate-warning mode shows "Save anyway", keep the same icon convention on that primary action.

---

## Acceptance criteria

- [ ] Super admin can register a patient by selecting tenant (and facility) — no "Tenant is required" API error when fields are filled.
- [ ] Single-facility staff see a simplified form (no tenant/facility pickers); registration succeeds with session scope pre-filled.
- [ ] Required visible fields show required indicators and block submit when empty.
- [ ] Form feedback uses the new horizontal, color-coded banner component.
- [ ] Register patient submit button shows `person_add_alt_1_outlined`; Cancel button removed from dialog footer.
- [ ] Widget tests updated for multi-tenant and single-facility registration paths.
- [ ] Quality gate passes: `dart format`, `flutter analyze`, `flutter test`.

---

## Key files

```
frontend/lib/shared/patient_actions/register_new_patient_dialog.dart
frontend/lib/shared/patient_actions/patient_registration_facility_scope.dart
frontend/lib/shared/components/app_state_view.dart          # current AppFailureStateView
frontend/lib/core/errors/validation_message_presenter.dart
frontend/lib/core/permissions/access_policy.dart
frontend/lib/features/patients/domain/entities/patient_entities.dart  # PatientReferenceData
backend/src/modules/patient/controllers/patient.controller.js         # tenant_id scope rules
```
