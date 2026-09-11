# 24 — Change the Active Toggle to a Checkbox

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 7, Step 24
**Depends on:** 18
**Applies to:** development and production

## Context

Edit Facility presents the Active state as a toggle. It must become a checkbox that defaults to checked for new facilities, while mapping to the same backend field with no compatibility break for existing records.

## Requirements

1. Replace the Active toggle in Edit Facility with the shared checkbox component from the design system.
2. Default the checkbox to checked when creating a facility; when editing, reflect the stored value exactly.
3. Map the checkbox to the existing backend active field with no change to the API contract or stored representation.
4. Preserve the confirmation or warning behavior, if any, that currently accompanies deactivating a facility.
5. Label the control clearly, localize the label and any helper text, and keep the layout consistent with neighbouring form fields.
6. Ensure keyboard and screen-reader accessibility: focusable, togglable by keyboard, with an accessible label.
7. Verify that deactivating a facility still has the same downstream effect it has today, and that no record loses its current state during the change.
8. Add a widget test for default-checked on create, correct reflection on edit, and correct submitted value.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the shared checkbox component; do not style a bespoke control.
- Do not change the semantics of the active field or introduce a new status vocabulary.
- Follow `prompts/.cursor/forms.mdc`, `localization.mdc`, `theming.mdc`, and `responsiveness.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R5)** Edit Facility renders a labelled, localized checkbox in place of the toggle, consistent with adjacent fields.
- [ ] **AC2 (R2)** Creating a facility starts checked; editing reflects the stored value.
- [ ] **AC3 (R3)** The submitted payload matches the previous contract exactly.
- [ ] **AC4 (R4, R7)** Deactivation behavior and downstream effects are unchanged, and no existing record changes state as a result of this work.
- [ ] **AC5 (R6)** The control is keyboard operable and exposes an accessible label.
- [ ] **AC6 (R8)** The new widget test passes.
- [ ] **AC7 (R9)** Behavior is identical in development and production after deployment.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: create and edit a facility in both environments, in both themes, at representative viewports, using keyboard only.

## Rollout — Development and Production

- Behavior must be identical under both Flutter define files.
- Config: none expected.
- Schema/data: none; the existing active field is reused unchanged.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, then confirm the control and stored values in production.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/shared/components/`, `frontend/lib/shared/forms/`
- `frontend/lib/l10n/app_en.arb`
- `backend/src/modules/facility/schemas/`
