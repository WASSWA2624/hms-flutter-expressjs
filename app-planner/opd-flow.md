You are working on the HOSSPI Hospital Management System codebase.

Before implementing, review the current app-planner, backend, frontend, and any attached latest screenshots. Align the work with the existing Flutter/Riverpod implementation, current `AppWorkspace` layout pattern, shared components, and existing table/search/filter behavior.

## Goal

Update the workspace summary cards on the listed module screens so they behave consistently:

- Summary cards must update/filter the table on the current main screen.
- Summary cards must not open modal dialogs.
- Each screen must have an “All” summary card for the full table/list for that screen.
- Zero-value summary cards must not be displayed.
- Every visible summary card must be clickable.
- Informational-only summary cards that cannot update the table must be removed.
- Summary value badges must display plain text only, without a filled badge background.
- On small screens, compact summary cards must show only the icon and value, without the full card/badge background.

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

## Shared component to update

Use the existing shared summary-card implementation:

- `lib/shared/layout/app_workspace.dart`
- `AppWorkspace`
- `AppWorkspaceSummaryGrid`
- `AppWorkspaceSummaryCard`
- `_SummaryCardBody`
- `_SummaryIconTile`
- `_SummaryValueBadge`

Update the shared component styling so the summary-card changes apply consistently across the listed screens.

## Required card behavior

### 1. Card clicks must update the main table

When a user clicks a summary card, update the current screen’s table/list filter instead of opening a modal.

Use existing controller or local filter methods where available, such as:

- `applyQuery`
- `applyScope`
- `applyFilter`
- `applyStatus`
- `applyStage`
- `applyQueue`
- existing local table filter notifiers such as OPD’s `_setFilter`

Do not keep summary-card click handlers that call modal-opening methods.

Examples of current modal-based summary behavior to replace:

- Patients: summary cards currently call `_openSummaryPatientList` or `_openDuplicateReview`.
- OPD: summary cards currently call `_openSummaryPatientList`.
- Clinical: summary cards currently call `_openSummaryWorklistDialog`.
- Nursing: summary cards currently call `_openSummaryPatientsDialog`.

Those summary cards should update the main table instead.

Row actions, detail dialogs, create/edit dialogs, and normal workflow action dialogs are not part of this change.

### 2. Add an “All” summary card on each listed screen

Each listed screen must include one summary card that represents the full table/list for that screen.

Examples:

- Patients: All patients
- Billing: All billing work items
- Claims: All claims/authorization work items
- OPD: All OPD records/patients shown by the workspace table
- Emergency: All emergency board records
- IPD: All admissions/patients
- ICU: All ICU records/patients
- Nursing: All nursing worklist records/patients
- Clinical: All clinical worklist records
- Lab: All lab orders
- Radiology: All radiology orders
- Pharmacy: All pharmacy orders
- Discharge: All discharge records
- Theatre/Theater: All theatre cases

Clicking the “All” card must clear the card-applied category/status/scope filter and show the full table/list for that screen.

### 3. Hide zero-value cards

Do not render a summary card when its represented count or amount is zero.

Use the raw numeric value before formatting to decide whether to hide the card.

Examples:

- Count `0` → hide the card.
- Currency/amount `0` → hide the card.
- “All” card with total `0` → hide the card.

Do not display empty zero-value cards just to preserve layout spacing.

### 4. Every visible summary card must be clickable

Every visible summary card must have an `onPressed` action that updates the current table/list.

If a card is currently informational only and does not have a matching table filter behavior, remove it from the summary-card list instead of leaving it non-clickable.

Do not leave visible summary cards with `onPressed: null`.

### 5. Remove summary value badge background

Update `_SummaryValueBadge` so the displayed value is plain text only.

Remove the filled background, border, and badge container styling behind the value.

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

Keep tooltip/semantic labeling so the card remains understandable and accessible on small screens.

## Current implementation notes

Use the current implementations as anchors:

- Billing, Emergency, IPD, ICU, Lab, and some Pharmacy cards already update the table through existing controller filters/scopes.
- Claims, Radiology, Discharge, and Theater cards currently include informational cards without `onPressed`.
- Patients, OPD, Clinical, and Nursing currently use summary-card clicks to open modal dialogs.
- `compactSummaryCards: true` is already used across these workspace screens.
- `tenant_facility_setup_page.dart` also uses summary cards, but it must not be changed for this task.

## Implementation rules

- Reuse `AppWorkspaceSummaryCard`; do not create a separate summary-card component for these screens.
- Keep the existing labels, icons, tones, formatting, search behavior, pagination behavior, table components, and workspace layout unless the change is required by this prompt.
- Preserve existing permissions, row actions, workflow dialogs, controller/repository calls, and mutation behavior.
- Do not replace current tables with new table components.
- Do not introduce new dashboards or extra summary sections.
- Do not add Settings or Setup changes.
- Keep the UI less congested by rendering only useful, non-zero, clickable summary cards.

## Acceptance criteria

- Listed screens only are updated.
- Settings, Setup, and Tenant Facility setup are untouched.
- Every visible summary card is clickable.
- No summary card opens a modal dialog.
- Clicking a summary card updates the current screen’s main table/list.
- Each listed screen has an “All” card when the all-count is non-zero.
- Zero-count and zero-amount cards are hidden.
- Informational-only summary cards are removed.
- Summary value badges show plain text without a filled badge background.
- On small screens, compact cards show only icon and value text without full card/badge background.
- Existing row/detail/workflow modals still work as before.