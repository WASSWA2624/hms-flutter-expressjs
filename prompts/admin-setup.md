# Remove HR-only `/admin/setup` path

Make Admin Setup permission-driven only: drop the HR-only body, Manage cards, and detail modals so access follows permissions, not HR role identity.

## Context

- Inventory: `screens/admin-setup.md`. Desk tabs (`_SetupBody`) are primary; wizard unused.
- `isHrFacilitySetupOnlyUser()` swaps the desk for `_HrFacilitySetupBody` (Departments/Units Manage → detail dialogs).
- `canManageHrFacilitySetup()` requires `AppRole.hr`; setup must not branch on HR-only identity.

## Requirements

1. Remove `_HrFacilitySetupBody` and its Manage → departments/units detail-dialog path.
2. Stop gating setup chrome, title, toolbar, or sections on `isHrSetupOnly` / `isHrFacilitySetupOnlyUser()`.
3. Drive section visibility and structure mutate via permission grants only; reuse `tenantFacilityVisibleSetupDeskSections` and `canEditFacilitySetupStructure` without `AppRole.hr`.
4. Permission-granted users see the normal desk for those grants, including when they also hold HR.
5. Users without those permissions get no HR-only substitute; empty/forbidden follow workspace rules.
6. Preserve shared-desk loading, empty, error (Try again), success, and validation feedback.

## Constraints

- Follow Prompt Definition Standards; reuse desk panels, dialogs, RBAC/ABAC, routes, theme tokens.
- Do not restore the wizard or refactor unrelated catalog/access-admin flows.
- Backend remains authoritative; omit unauthorized sections and “no access” chrome.

## Acceptance Criteria

- AC1→R1: HR-only body and Manage buttons/modals are gone from `/admin/setup`.
- AC2→R2–R3: Setup UI and policy helpers are permission-based, not HR-role-only.
- AC3→R4–R5: Authorized desk remains; unauthorized and HR-only UI are absent.
- AC4→R6: Shared-desk UI states still work.
- AC5: Tests prove unauthorized/HR-only UI absent and authorized desk present; viewports/themes.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/test/features/tenant_facility/`
- `screens/admin-setup.md`
