# Refine Tenant details layout — `/admin/setup?section=tenants`

Update the **Tenant details** dialog: borderless split panes, vertical separator, independent scroll, facilities on current `AppListTable`.

## Context

- Tenants tab → row → `Tenant details` (`_TenantDetailsDialog`).
- Left `_TenantDetailsSummary`; right `_TenantDetailsFacilitiesPanel` (`AppListTable` + search).
- Both panes use outlined cards; wide `Row` has no divider.
- Reuse table contracts, permissions, mutations, hide/show summary, footers.

## Requirements

1. Remove outline/card borders (and radius chrome) from summary and facilities panes.
2. On wide layout, add a theme-token vertical separator between panes; keep spacing tokens.
3. Keep facilities on current `AppListTable` so search and body scroll up together; horizontal overflow stays with the table.
4. Make summary independently scrollable when content exceeds pane height.
5. Preserve load, empty, error/retry, filter, column settings, row actions, and unauthorized omission; no mutation or permission changes.
6. Keep narrow stacking without clipping; use theme tokens for light and dark.

## Constraints

- Layout/chrome only in Tenant details; no route, API, or RBAC changes; no unrelated refactors.

## Acceptance Criteria

- No outline card borders on either pane.
- Wide layout shows a vertical separator between panes.
- Facilities search + rows scroll together; summary scrolls independently when needed.
- Extra columns still scroll horizontally in the table.
- Existing states, actions, and auth visibility unchanged.
- Manual check: wide/narrow, light/dark.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `screens/admin-setup.md`
