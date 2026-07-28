# Refine Clinical Workspace Tabs and Chrome

Make `/clinical` tab worklists accurate for outpatient clinical queues, remove cross-module tab-strip shortcuts, and keep Filters and table Settings comprehensive.

## Context

- Target: `/clinical` (`ClinicalWorkspacePage`). Inventory: `screens/clinical.md`.
- Tabs: **Follow-ups**, **All**, **Waiting review**, **Urgent**, **Results ready**, **In consultation**, **Completed**.
- **Outpatient clinical encounter**: non-IPD encounter awaiting or assigned a doctor from OPD or another outpatient department. Exclude inpatient/IPD.
- **Cross-module tab toolbar actions**: tab-strip **Refresh**, **OPD**, **Lab**, and **Discharge** (those modules have their own screens).

## Requirements

1. Remove all cross-module tab toolbar primary and secondary actions (**Refresh**, **OPD**, **Lab**, **Discharge**) from every clinical section; keep tab switching and worklist chrome.
2. Scope **All** to outpatient clinical encounters only (exclude IPD/inpatient), including patients waiting for or already assigned a doctor.
3. Scope **Waiting review** to non-terminal outpatient encounters awaiting doctor review.
4. Scope **Urgent** to non-terminal outpatient encounters flagged urgent.
5. Scope **Results ready** to non-terminal outpatient encounters with diagnostic/lab results available for clinician review.
6. Scope **In consultation** to non-terminal outpatient encounters currently in consultation.
7. Scope **Completed** to outpatient encounters completed or dispositioned for the current local day.
8. Keep **Follow-ups** on its existing panel; do not add tab toolbar shortcuts there.
9. Ensure each worklist table shows only entries matching that section’s scope after search and filters; tab scope stays authoritative when filters apply.
10. Keep search-bar **Filters** comprehensive: text fields for patient/name, patient ID, phone, encounter #, queue, provider, status, location; option groups for source queue, status/stage, provider (including Unassigned), encounter type, location; date range; Apply and Clear; preserve tab scope.
11. Keep table **Settings** comprehensive: per-section column visibility with Apply, Reset, and Close covering all available clinical columns for that section.
12. Preserve RBAC/ABAC, write gates, loading/empty/error/success states, theme tokens, and responsive layout; unauthorized controls must not render.

## Constraints

- Reuse existing clinical worklist, filter, table, and dialog components; no unrelated refactors.
- Do not remove in-row `WorkflowActionButton` or encounter-dialog workflow navigation actions.
- Backend permissions remain authoritative via existing checks.
- Follow `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

- Tab strip shows no **Refresh**, **OPD**, **Lab**, or **Discharge** on any clinical section (1, 8).
- **All**, **Waiting review**, **Urgent**, **Results ready**, **In consultation**, and **Completed** each list only matching outpatient entries; no IPD rows (2–7, 9).
- **Completed** lists only same-day completed/dispositioned outpatient encounters (7).
- Filters panel exposes the fields in requirement 10; Apply/Clear update the active tab’s list without changing section (9, 10).
- Settings lists all available columns for the section; Apply/Reset persist per `clinical_{section}` (11).
- Loading, empty, error, and success feedback still appear; unauthorized UI remains absent (12).
- Verify with tests for toolbar absence, IPD exclusion, and section scope, plus manual checks on mobile/tablet/desktop and light/dark.

## Relevant Files

- `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
- `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart`
- `frontend/lib/features/clinical/domain/entities/clinical_entities.dart`
- `screens/clinical.md`
- Clinical worklist/filter tests under `frontend/test/`
