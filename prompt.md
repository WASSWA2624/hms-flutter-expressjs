# Patient registration form refinements

Improve duplicate-warning behavior and tenant/facility picker UX on the patient registration modal dialog.

## Scope

Primary: `frontend/lib/shared/patient_actions/register_new_patient_dialog.dart` (`RegisterNewPatientForm`, `RegisterNewPatientDialog`).

Also align any parallel registration UI (e.g. `patient_registry_page.dart`) if it duplicates the same patterns.

## 1. Reset duplicate warning when the form changes

**Current behavior:** When a potential duplicate is found, a warning banner appears and the primary action label changes to **Register anyway** / **Save anyway**.

**Required behavior:** If the user edits any registration field after that warning is shown:

1. Dismiss the duplicate warning banner immediately.
2. Clear duplicate state (`_duplicateCandidates`, `_duplicateWarningAccepted`).
3. Restore the primary button label to **Register patient** / **Save**.
4. Require a fresh duplicate check on the next submit attempt.

**Rationale:** Edited data may no longer match the flagged duplicate.

**Implementation notes:**

- Extend `_clearDuplicateWarning` (or equivalent) to all fields that affect duplicate matching or form identity—not only first name, last name, phone, and identifier value. Include at minimum: date of birth, gender, email, tenant, facility, and any other editable registration inputs.
- Ensure the warning panel hides when duplicate state is cleared.



## 2. Disable facility until a tenant is selected

**When:** Tenant and facility pickers are both visible (`PatientRegistrationScope.showTenantPicker` and `showFacilityPicker`).

**Required behavior:**

1. If no tenant is selected, the facility field is **disabled** (not merely empty).
2. On hover/focus of the disabled facility field, show helper text such as: **“Please select a tenant first.”** (Add l10n string if needed.)
3. When the tenant changes:
  - Clear the facility selection.
  - Repopulate the facility dropdown with `PatientRegistrationScope.facilitiesForTenant(...)` for the new tenant.
  - Keep facility disabled until a tenant is selected.

**Acceptance criteria**

- [ ] Editing any field after a duplicate warning clears the banner and resets the submit button label.
- [ ] Submitting again re-runs duplicate lookup before saving.
- [ ] Facility picker is disabled with tooltip when tenant is unset.
- [ ] Changing tenant clears facility and shows only facilities for the selected tenant.
- [ ] Existing tests pass; add/update widget tests for the new behavior where practical.