# Refine Tenant details dialog on `/admin/setup`

Improve Tenants-tab **Tenant details**: richer collapsible left summary; facilities Filter/Settings, sort, row → Facility details.
## Context

- Entry: Tenants desk → `showTenantDetailsDialog` (`_TenantDetailsDialog`).
- Left `_TenantDetailsSummary` is sparse; right `_TenantDetailsFacilitiesPanel` lacks Filter/Settings, sort, row select.
- Reuse Facility details and Filter/Settings from manage tenants/facilities panels; hide unauthorized controls.

## Requirements

1. Restyle left summary with theme tokens; show available registration fields (name, slug, ID, status, contact name, email, phone, other persisted fields); empty as em dash.
2. Add hide/show for left summary so facilities table expands.
3. Add **Filter** and **Settings** on facilities search (same as other setup tables). Default = all statuses. Settings = column visibility.
4. Keep search; add column sort; default = facility name ascending.
5. Non-deleted facility row opens existing Facility details; keep authorized Edit/Delete.
6. Cover loading, empty, error (+ retry); refresh after nested mutations.
7. Responsive mobile/tablet/desktop; light and dark themes.

## Constraints

- Scope: Tenant details and nested facility flows only.
- Reuse dialogs, table/search/filter/settings, l10n, auth; no unrelated refactors.
- Extend existing tenant/contact payloads; do not invent fields.

## Acceptance Criteria

- Summary polished with registration/contact fields; hide/show expands table (R1–R2).
- Filter defaults to all; Settings toggles columns; sort defaults to name (R3–R4).
- Row opens Facility details; Edit/Delete when allowed (R5).
- Loading/empty/error/retry and post-mutation refresh; unauthorized actions hidden (R6–R7).
- Manual: light/dark, narrow/wide; unauthorized user has no mutate controls.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `screens/admin-setup.md`
