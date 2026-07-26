# Action inventory — `/admin/setup?section=departments`

## Department list

- **Add department**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when `canEditFacilitySetupStructure()` and a facility is available, and while no structure mutation is submitting; enabled when a facility id is present.
  - Immediate result: Opens `_DepartmentFormDialog` in **Add department** mode.

- **Edit**
  - Location: Active department row actions.
  - Condition: The actions column is shown when `canEditFacilitySetupStructure()` and a facility is available, and while no structure mutation is submitting; shown only for non-deleted departments.
  - Immediate result: Opens `_DepartmentFormDialog` in **Edit department** mode.

- **Delete**
  - Location: Active department row actions.
  - Condition: Shown when `canEditFacilitySetupStructure()` and a facility is available, and while no structure mutation is submitting; shown only for non-deleted departments.
  - Immediate result: Opens the soft-delete department `AppConfirmActionDialog`.

- **Restore**
  - Location: Soft-deleted department row actions.
  - Condition: Shown when `canEditFacilitySetupStructure()` and a facility is available, and while no structure mutation is submitting; shown only for soft-deleted departments.
  - Immediate result: Opens the restore department `AppConfirmActionDialog`.
