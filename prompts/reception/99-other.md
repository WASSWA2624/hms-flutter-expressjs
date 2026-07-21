# Standardize Admin Setup Tab Toolbars and Tables

Unify `/admin/setup` so every desk tab shares one toolbar and table pattern. Follow `prompts/.cursor/prompt.mdc`.

## Context

**Desk tabs:** Tenants, Branches, Facility, Departments, Units, Wards, Rooms, Beds, Roles, Permissions, Users.

Add/Create lives in tab bodies. Entity-specific row labels (`Edit tenant`) overflow. Some tabs lack `AppListTable` Filters/Settings. `AppTabStrip` already supports `primaryAction` and `secondaryActions`.

## Requirements

1. Move each authorized Add/Create into that tab’s `AppTabStrip.primaryAction` as `AppButton.primary` with the existing add label and icon; remove body duplicates.
2. Keep Refresh (and catalog config when applicable) in `secondaryActions`; never demote Add.
3. Render each tab’s records with `AppListTable`, including search plus Filters/Settings when columns or filter groups exist.
4. Use generic **Edit** and **Delete** row labels with design-system icons; keep entity-specific titles only on dialogs.
5. Fit row actions without overflow across viewports.
6. Preserve loading, empty, error, success, validation, busy, and permission states; omit unauthorized Add/Edit/Delete; synchronize after mutations.

## Constraints

- Reuse `AppTabStrip`, `AppButton`, `AppListTable`, setup/access-admin panels, dialogs, localization, auth, and theme tokens; no parallel tables or toolbars.
- Do not change mutation contracts, soft-delete rules, or permission-based tab visibility.

## Acceptance Criteria

- R1–R2: Authorized Add/Create is the tab primary action only; Refresh stays secondary.
- R3–R5: Tables expose Filters/Settings when applicable; generic Edit/Delete never overflow.
- R6: States/sync intact; unauthorized actions absent.
- Update setup/access-admin tests; run Flutter analysis; check each tab on narrow/wide viewports light/dark.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/shared/components/app_tab_strip.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/test/features/tenant_facility/`
