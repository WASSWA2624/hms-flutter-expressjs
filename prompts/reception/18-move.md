# Tighten Assign/Change Doctor Dialog Context and Search

Simplify Assign/Change doctor patient context and fix doctor search empty states. Follow `prompts/.cursor/prompt.mdc`.

## Context

**Assign/Change doctor** shows heavy encounter context: payment amount, journey stepper, and expanded pairs. Doctor search filters, but unmatched queries leave empty menu chrome instead of clear feedback.

**Patient context:** identity via shared `AppPatientDetails`; no payment amount or journey stepper here.

## Requirements

1. Confirm patient identity reuses shared `AppPatientDetails` (via OPD action context); do not invent a parallel header.
2. Hide payment/amount display in this dialog’s context.
3. Omit the visit journey / progress stepper in this dialog.
4. Keep the searchable doctor select typeable and filterable; remove leftover empty menu space when filtered results are empty.
5. When a query matches no doctors, show a localized empty-results message in the menu instead of an empty list.
6. Preserve validation, loading, busy, success, error, and permission behavior; synchronize after save; omit unauthorized UI.

## Constraints

- Reuse `AppPatientDetails`, OPD action context, provider options, localization, and design-system tokens; no new assign contracts.
- Do not change Queue Actions status radios or clinical stages.
- Support themes and viewports.

## Acceptance Criteria

- R1–R3: Shared patient details only; no payment amount or journey stepper.
- R4–R5: Search filters cleanly; no-results message when unmatched; no empty menu gap.
- R6: States and sync unchanged; unauthorized UI absent.
- Update assign-doctor, select-field, related tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_action_context.dart`
- `frontend/lib/shared/components/app_patient_details.dart`
- `frontend/lib/shared/components/app_select_field.dart`
- `frontend/test/shared/opd_actions/`
