You are working on the HOSSPI Hospital Management System codebase.

Before implementing, review the current app-planner, backend, frontend, and any attached latest screenshots. Align the work with the existing Flutter/Riverpod implementation, current `AppWorkspace` layout pattern, shared components, and existing table/search/filter behavior.

## Goal

Audit and complete the workspace summary-card behavior across the listed module screens.

Summary cards must behave consistently:

- Summary cards must update/filter the table or list on the current main screen.
- Summary cards must not open modal dialogs.
- Each listed screen must have an “All” summary card for the full table/list on that screen.
- Zero-value summary cards must not be displayed.
- Every visible summary card must be clickable.
- Informational-only summary cards that cannot update the table/list must be removed.
- Summary values must display as plain text without a filled badge background.
- On small screens, compact summary cards must show only the icon and value text, without the full card/badge background.

If a listed screen already satisfies a requirement, preserve the existing implementation.

## Screens to update

Update these screens only:

- Patients: `lib/features/patients/presentation/pages/patient_registry_page.dart`
- Billing: `lib/features/billing/presentation/pages/billing_workspace_page.dart`
- Claims: `lib/features/claims/presentation/pages/claims_workspace_page.dart`
- OPD: `lib/features/opd/presentation/pages/opd_workspace_page.dart`
- Emergency: `lib/features/emergency/presentation/pages/emergency_workspace_page.dart`
- IPD: `lib/features/ipd/presentation/pages/ipd_workspace_page.dart`
- ICU: `lib/features/icu/presentation/pages/icu_workspace_page.dart`
- Nursing: `lib/features/nursing/presentation/pages/nursing_workspace_page.dart`
- Clinical: `lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
- Lab: `lib/features/lab/presentation/pages/lab_workspace_page.dart`
- Radiology: `lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
- Pharmacy: `lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- Discharge: `lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
- Theatre/Theater: `lib/features/theater/presentation/pages/theater_workspace_page.dart`

Do not update Settings, Setup, or Tenant Facility setup screens.

Do not edit:

- `lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`

## Shared component anchors

Use the existing shared summary-card implementation:

- `lib/shared/layout/app_workspace.dart`
- `AppWorkspace`
- `AppWorkspaceSummaryGrid`
- `AppWorkspaceSummaryCard`
- `_SummaryCardBody`
- `_SummaryIconTile`
- `_SummaryValueBadge`

Use the shared component for styling and layout consistency.

Do not create a new summary-card component.

Do not implement zero-value hiding inside `AppWorkspaceSummaryCard`, because that would affect screens outside this task. Hide zero-value cards in each listed screen’s `summaryCards` construction by checking the raw numeric value before formatting.

## Current implementation anchors

Use the existing filter/update methods already present in each module.

Examples:

- Patients: use `_applySummaryQuery(...)` and `PatientListQuery(...)`
- Billing: use `_summaryCards(...)` and `controller.applyQueue(...)`
- Claims: use `_applySummaryFilter(...)` and `ClaimsQueueFilter`
- OPD: use `_applySummaryFilter(...)` and `_OpdTableFilter`
- Emergency: use `controller.applyScope(EmergencyBoardScope...)`
- IPD: use `controller.applyScope(IpdQueueScope...)`
- ICU: use `controller.applyScope(IcuBoardScope...)`
- Nursing: use `_summaryCard(...)` and `controller.applyScope(NursingQueueScope...)`
- Clinical: use `controller.applyScope(ClinicalQueueScope...)`
- Lab: use `_summaryCard(...)` and `controller.applyScope(LabQueueScope...)`
- Radiology: use `controller.clearFilters` and `controller.applyStage(...)`
- Pharmacy: use `controller.applyFilter(PharmacyOrderFilter...)`
- Discharge: use `controller.applyStatus(DischargeStatusFilter...)`
- Theater: use `controller.clearFilters` and `controller.applyStatus(...)`

Preserve existing controller calls, failure handling, loading behavior, refresh behavior, pagination behavior, search behavior, and table components.

## Required behavior

### 1. Card clicks must update the main table/list

When a user clicks a summary card, update the current screen’s table/list filter.

Do not open a modal from a summary-card click.

Do not use modal-opening methods as summary-card `onPressed` handlers.

Row actions, detail dialogs, create/edit dialogs, and workflow action dialogs are not part of this change and must continue working as before.

### 2. Each screen must have an “All” summary card

Each listed screen must include one summary card representing the full table/list for that screen.

Examples:

- Patients: all patients
- Billing: all billing work items
- Claims: all claims/authorization work items
- OPD: all OPD records/patients shown by the workspace table
- Emergency: all emergency board records
- IPD: all admissions/patients
- ICU: all ICU records/patients
- Nursing: all nursing worklist records/patients
- Clinical: all clinical worklist records
- Lab: all lab orders
- Radiology: all radiology orders
- Pharmacy: all pharmacy orders
- Discharge: all discharge records
- Theater: all theater cases

Clicking the “All” card must clear the card-applied category/status/scope filter and show the full table/list for that screen.

### 3. Hide zero-value cards

Do not render a summary card when its represented raw numeric value is zero.

Examples:

- Count `0` → hide the card.
- Amount `0` → hide the card.
- “All” total `0` → hide the card.

Do not display zero-value cards just to preserve spacing.

### 4. Every visible summary card must be clickable

Every visible summary card must have an `onPressed` action.

That action must update/filter the current table/list.

If a card is informational only and has no matching table/list filter behavior, remove it from the summary-card list.

Do not leave visible summary cards with `onPressed: null`.

Do not make a card clickable by opening a dialog.

### 5. Summary values must be plain text

Ensure `_SummaryValueBadge` displays the value as plain text only.

Do not show a filled background, border, pill, or badge container behind the value.

Keep the value readable, themed, accessible, and aligned with the existing summary-card design.

### 6. Small-screen compact behavior

For compact summary cards on small screens, show only:

- the icon
- the value text

Do not show:

- card label
- description
- status line
- chevron
- filled card background
- card border
- card shadow
- filled value badge background

Keep tooltip/semantic labeling so the card remains understandable and accessible.

## Implementation rules

- Reuse `AppWorkspaceSummaryCard`.
- Reuse existing screen-level filter/query/scope/status methods.
- Keep existing labels, icons, tones, formatting, permissions, and localization keys unless a change is required by this task.
- Preserve existing search, filter, pagination, table, row action, detail dialog, and workflow dialog behavior.
- Preserve existing backend/API behavior.
- Do not add backend routes.
- Do not add new workflows.
- Do not add new permissions.
- Do not add new fields.
- Do not add new API calls.
- Do not replace current tables with new table components.
- Do not introduce new dashboards or extra summary sections.
- Do not edit Settings, Setup, or Tenant Facility setup screens.

## Acceptance criteria

- Only the listed screens are updated.
- Settings, Setup, and Tenant Facility setup are untouched.
- Every visible summary card is clickable.
- No summary card opens a modal dialog.
- Clicking a summary card updates the current screen’s main table/list.
- Each listed screen has an “All” card when the all-count is non-zero.
- Zero-count and zero-amount cards are hidden.
- Informational-only summary cards are removed.
- Summary values show plain text without a filled badge background.
- On small screens, compact cards show only icon and value text without full card/badge background.
- Existing row/detail/workflow modals still work as before.
- No backend behavior, workflow behavior, permission behavior, API call, payload shape, or table behavior is changed.