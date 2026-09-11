# 21 — Improve the Staff List and Add Nested Staff Details

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 6, Step 21
**Depends on:** 20
**Applies to:** development and production

## Context

The facility staff list has misaligned, cramped action buttons, and staff rows are not openable. Clicking a row should open the existing Staff Details UI as a nested dialog over Facility Details without discarding the underlying state.

## Requirements

1. Fix action-button spacing, alignment, and wrapping in the staff list so controls are consistently sized and aligned at every supported viewport.
2. Make the staff row itself activatable (tap, click, keyboard Enter) to open Staff Details, while keeping row actions individually operable without triggering the row action.
3. Reuse the existing Staff Details UI as a nested dialog; do not build a second staff detail view.
4. Preserve the Facility Details state beneath the nested dialog: scroll position, filters, selected tab, and loaded data must survive open and close.
5. Load only the data Staff Details needs; do not refetch unrelated Facility Details data when the nested dialog opens or closes.
6. Apply permission gating so the row opens only for users authorized to view staff details, and unauthorized actions do not render.
7. Render loading, empty, error, and success states inside the nested dialog, and keep dialog nesting depth and dismissal behavior compliant with the dialog rules.
8. Add frontend tests for row activation, nested dialog rendering, underlying-state preservation, and permission gating.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Follow `prompts/.cursor/tables.mdc` and `dialogs.mdc` for row interaction, action layout, and nesting.
- Reuse shared table and dialog components; no bespoke layout for this list.
- Do not introduce a full page navigation as a substitute for the nested dialog.

## Acceptance Criteria

- [ ] **AC1 (R1)** Action buttons are aligned and legible at mobile, tablet, and desktop widths in both themes.
- [ ] **AC2 (R2, R3)** Clicking or keyboard-activating a row opens the existing Staff Details as a nested dialog; row actions still work independently.
- [ ] **AC3 (R4)** After closing the nested dialog, Facility Details retains scroll position, filters, tab, and data.
- [ ] **AC4 (R5)** Opening the nested dialog issues only staff-detail requests, verified in the network log.
- [ ] **AC5 (R6)** An unauthorized user cannot open staff details, and the row action does not render.
- [ ] **AC6 (R7)** All dialog states render correctly.
- [ ] **AC7 (R8)** New tests pass.
- [ ] **AC8 (R9)** The behavior is identical in development and production after deployment.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: staff list interaction in both environments, at representative viewports, in light and dark themes, with keyboard-only navigation.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: no environment-specific behavior is permitted; document any new key in the relevant env files if one is introduced.
- Schema/data: no schema change is expected; if a staff-detail endpoint is added, apply and deploy it with the standard migration commands.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, plus `python deploy/deploy-backend.py` when the API changes, then repeat the interaction checks in production.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/hr/presentation/`
- `frontend/lib/shared/management/`, `frontend/lib/shared/widgets/`, `frontend/lib/shared/layout/`
- `backend/src/modules/staff-profile/`, `hr-workspace/`
