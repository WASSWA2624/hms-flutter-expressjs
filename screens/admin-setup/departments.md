# Action inventory — `/admin/setup?section=departments`

## Department list

- **Create department**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when `canEditFacilitySetupStructure()`; enabled when a facility id is present and no structure mutation is submitting; when authorized without a facility, shown disabled with the facility prerequisite message.
  - Immediate result: Opens `_DepartmentFormDialog` in **Create department** mode.

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
