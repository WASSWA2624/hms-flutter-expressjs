# Tenant & facility setup — completion prompt

## Goal
Finish the post-subscription **Tenant and facility setup** flow so a paying tenant admin can fully configure their organization before daily operations. The guided wizard already exists; close the gaps below and verify end-to-end create/update behavior.

## Entry & access
- Screen: **Settings → Tenant and facility setup** (`tenant_facility_setup_page.dart`, route `AppRoutes.tenantFacilitySetup`).
- Available to authenticated users with tenant/facility admin access (see `TenantFacilityPermissions`).
- Follow the existing 4-step wizard order:
  1. Tenant profile  
  2. Facility identity  
  3. Departments and units  
  4. Wards, rooms, and beds  

## Requirements

### 1. Tenant profile
- Allow updating **tenant name** and **slug**.
- Persist changes via `TenantFacilitySetupController` and confirm success/error feedback.
- Mark checklist item *“Tenant profile is configured”* when valid data is saved.

### 2. Facility identity
- Allow updating **facility name**, **type**, **contact details** (email, phone), and **address**.
- **Facility type selector**: use `FacilitySetupType` values (hospital, clinic, lab, pharmacy, other) and show a **distinct icon per type** in the selector/modal (not text-only).
- **Logo**: replace the manual **logo URL** text field with **image upload** (pick file → preview → upload). Reuse the `file_selector` + bytes upload pattern from `subscription_upgrade_dialog.dart`. Store via the approved storage service and persist the returned URL in `logoUrl`. Update l10n copy (remove “enter URL” helper; describe upload instead).
- Ensure saved logo appears wherever facility branding is shown in-app.

### 3. Departments and units
- Support **create, edit, and delete** departments and units for the current facility.
- **Reuse existing HR/facility-structure UI** where possible (e.g. department/unit dialogs and selectors from the HR module) instead of duplicating forms.
- Units must remain scoped to their parent department.
- Mark checklist item *“Departments and units are configured”* when at least one department and one unit exist.

### 4. Wards, rooms, and beds
- Implement the hierarchy: **ward → room → bed** (add/edit/delete at each level).
- Enforce parent relationships (room belongs to ward; bed belongs to ward and optionally room).
- Mark checklist item *“Rooms, wards, or beds are configured”* when at least one ward, room, or bed exists.

## Engineering constraints
- Keep logic in `tenant_facility_setup_controller.dart`; avoid parallel implementations.
- Add/update l10n strings in `app_en.arb` (and generated localizations).
- Match existing app patterns: `showAppDialog`, `AppSelectField`, shared form components, theme tokens.
- Add or extend widget/controller tests for new upload and wizard-completion behavior.
- Backend: align logo upload with existing `logo_url` field in tenant-facility workspace APIs if an upload endpoint is needed.

## Acceptance criteria
- [ ] A subscribed tenant admin can complete all four wizard steps without errors.
- [ ] Facility type shows icons; logo is uploaded (not typed as a URL).
- [ ] Departments, units, wards, rooms, and beds can be added and persist after reload.
- [ ] Setup checklist and wizard both reflect accurate completion state.
- [ ] No duplicated department/unit form code where HR widgets can be shared.
- [ ] Relevant tests pass (`flutter test` for touched areas).

## Key files
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_wizard.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/features/hr/presentation/widgets/` (department/unit dialogs to reuse)
- `frontend/lib/features/subscriptions/presentation/widgets/subscription_upgrade_dialog.dart` (file upload reference)
