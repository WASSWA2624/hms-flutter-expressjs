You are working inside the hms folder, which contains app-planner, backend, and frontend.

Review the current OPD implementation and fix the OPD consultation billing and existing-encounter handling issues shown in the provided screenshots.

Relevant current areas to inspect include:
- frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart
- frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart
- frontend/lib/features/opd/data/dtos/opd_dtos.dart
- frontend/lib/features/opd/domain/entities/opd_entities.dart
- backend/src/modules/opd-flow/services/opd-flow.service.js
- backend/src/modules/opd-flow/repositories/opd-flow.repository.js
- Any related billing, payment, appointment, patient, or encounter files needed for the existing implementation.

Issue 1: Paid consultation amount is missing in OPD list

On the OPD screen, the Payer / billing column correctly shows some patients as paid, but some paid patients do not show the amount they paid.

Examples from the screenshots:
- Joshua Suuna shows Paid, but no paid amount.
- Cheke Cheka shows Paid, but no paid amount.
- Grace Demo-Delta shows Completed, but no paid amount.
- Nia Demo-Charlie correctly shows Paid | UGX20,000.

Fix this so that when a patient has paid the consultation fee, the OPD list displays both the paid status and the paid consultation amount whenever that amount exists in the current billing/payment/invoice/OPD flow data.

Expected result:
- Paid consultation rows should not only show Paid or Completed.
- They should show the paid consultation amount beside the status, similar to Paid | UGX20,000.
- Do not display a fake amount if the real amount cannot be resolved from existing data.

Issue 2: Start OPD walk-in form should recognize existing active encounters

When the user clicks Start walk-in and selects a patient under Existing patient, some selected patients may already have an active/open OPD encounter.

Currently, the form does not clearly show that the selected patient already has an existing OPD encounter, and the user cannot easily see or reuse the existing encounter details.

Fix the Start OPD walk-in dialog so that when an existing patient is selected:
- If the selected patient already has an active/open OPD encounter, the form should clearly show this somewhere in the dialog.
- The form should automatically populate available existing encounter information where applicable, instead of forcing the user to re-enter information already known by the system.
- The user should be able to understand that this patient already has an active OPD encounter before submitting the form.

Apply the same behavior under Appointment patient:
- When an appointment patient is selected and that patient already has an active/open OPD encounter, show that existing encounter information in the dialog.
- Automatically populate available existing patient/encounter/provider/billing-related information where applicable from the current system data.

Acceptance criteria:
- OPD paid consultation rows show the paid amount when available.
- Existing active OPD encounters are detected when selecting an existing patient in Start OPD walk-in.
- Existing active OPD encounters are detected when selecting an appointment patient in Start OPD walk-in.
- The dialog visibly communicates that the patient already has an existing OPD encounter.
- The dialog pre-fills available existing information from the system instead of leaving the user to re-enter it.
- Preserve the current OPD workflow, styling, architecture, and data patterns.
- Do not add unrelated features or redesign unrelated screens.