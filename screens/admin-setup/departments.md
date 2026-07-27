# Action inventory — `/admin/setup?section=departments`

## Department list

- **Create department**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when `canEditFacilitySetupStructure()`; enabled when no structure mutation is submitting; for facility admins also requires a session facility id (otherwise disabled with the facility prerequisite message). Platform and tenant admins can open create without a session facility and pick scope in the form.
  - Immediate result: Opens `_DepartmentFormDialog` in **Create department** mode (role-aware tenant/facility pickers, similarity review, then department details on success).

- **Row select**
  - Location: Department table row.
  - Condition: Always available for listed departments.
  - Immediate result: Opens department details dialog.

- **Edit**
  - Location: Active department row actions.
  - Condition: The actions column is shown when `canEditFacilitySetupStructure()`; enabled when no structure mutation is submitting; shown only for non-deleted departments.
  - Immediate result: Opens `_DepartmentFormDialog` in **Edit department** mode.

- **Delete**
  - Location: Active department row actions.
  - Condition: The actions column is shown when `canEditFacilitySetupStructure()`; enabled when no structure mutation is submitting; shown only for non-deleted departments.
  - Immediate result: Opens the soft-delete department `AppConfirmActionDialog`.

- **Restore**
  - Location: Soft-deleted department row actions.
  - Condition: The actions column is shown when `canEditFacilitySetupStructure()`; enabled when no structure mutation is submitting; shown only for soft-deleted departments.
  - Immediate result: Opens the restore department `AppConfirmActionDialog`.

- **Permanent delete**
  - Location: Soft-deleted department row actions.
  - Condition: The actions column is shown when `canEditFacilitySetupStructure()`; enabled when no structure mutation is submitting; shown only for soft-deleted departments.
  - Immediate result: Opens the permanent-delete `AppTextInputActionDialog`.
