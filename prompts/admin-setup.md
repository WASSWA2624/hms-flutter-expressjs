# Refine Tenant details dialog on `/admin/setup`

Improve the Tenants-tab **Tenant details** dialog: richer collapsible left summary, and facilities table Filter/Settings, sort, and row → Facility details.

## Context

- Opened from Tenants desk via `showTenantDetailsDialog` (`_TenantDetailsDialog`).
- Left: `_TenantDetailsSummary` (sparse). Right: `_TenantDetailsFacilitiesPanel` (search + table; no Filter/Settings, sort, or row select).
- Reuse `showFacilityDetailsDialog` and Filter/Settings patterns from `ManageTenantsPanel` / `ManageFacilitiesPanel`.
- Hide unauthorized mutate controls via existing tenant/facility manage permissions.

## Requirements

1. Restyle the left summary with theme tokens; show all available tenant registration fields (name, slug, ID, status, contact name, email, phone, other persisted create/edit fields); empty → em dash.
2. Add hide/show for the left summary so the facilities table can expand.
3. Add **Filter** and **Settings** on the facilities search bar (same labels/behavior as other setup tables). Default filter = all statuses (active, inactive, deleted). Settings = column visibility.
4. Keep search; add column sort; default sort = facility name ascending.
5. Non-deleted facility row select opens existing Facility details; keep authorized Edit/Delete row actions.
6. Handle loading, empty, error (+ retry); refresh facilities after nested mutations.
7. Responsive on mobile/tablet/desktop; light and dark themes.

## Constraints

- Scope: Tenant details and nested facility flows only.
- Reuse existing dialogs, table/search/filter/settings, l10n, and auth; no unrelated refactors.
- Extend existing tenant/contact payloads; do not invent fields.

## Acceptance Criteria

- Summary is polished and lists available registration/contact fields (R1).
- Hide/show toggles summary and expands the table (R2).
- Filter defaults to all; Settings toggles columns; sort defaults to name (R3–R4).
- Row opens Facility details; Edit/Delete remain when allowed (R5).
- Loading/empty/error/retry and post-mutation refresh work; unauthorized actions stay hidden (R6–R7).
- Manual: light/dark + narrow/wide; unauthorized user sees no mutate controls.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `screens/admin-setup.md`
