# Roles Tab — Create Scope Radios and Guided Identity Fields

Reorganize create-role scope on `/admin/setup?section=roles` so platform admins choose Platform, Tenant(s), or Facility(ies) via radios, with progressive pickers and clear guidance when identity fields are blocked.

## Context

- Inventoried in `screens/admin-setup/roles.md`. Create opens `showRoleMutationDialog` in **Create** mode.
- Today platform create uses a tenant dropdown plus Entire organization / One facility segmented controls; identity fields disable until scope is ready with little explanation (see current create dialog).
- Reuse `AppRadioGroup`. Existing roles require `tenant_id` and optional `facility_id`; extend create contracts only as needed for platform scope and multi-target selection. Keep similarity review and deferred permissions from the prior roles work.

## Requirements

1. Place an `AppRadioGroup` at the top of create Scope (replace Entire organization / One facility). Options by actor: **Platform** (platform/cross-tenant admins only), **Tenant(s)**, **Facility(ies)**. Omit radios the actor cannot use; do not show disabled unauthorized options.
2. **Platform**: no tenant or facility pickers; create a platform-scoped role. **Tenant(s)**: require selecting one or more tenants; the role is available to each selected tenant. **Facility(ies)**: require selecting one or more facilities; the role is available to each selected facility. Show only the pickers for the active radio.
3. Keep **Role name** and **Display name** required and **Description** optional; omit permission assignment on create. Enable identity fields only when the active scope’s required targets are selected (platform: immediately; tenant/facility: after valid multi-select).
4. When identity fields are blocked, do not leave them silently inert: show a compact guidance banner/message stating what to select first, and if the user focuses or taps a blocked field, reinforce that same guidance (validation/visible feedback). Cover loading, empty picker, error, and success states for target loads and save.
5. Preserve post-create list refresh, similarity review, and opening role details with Edit, Delete, and Add permissions.

## Constraints

- Reuse `AppRadioGroup`, role mutation/details dialogs, access-admin lookups, RBAC/ABAC, and role similarity; extend create payload/contracts only for platform scope and multi-tenant/multi-facility targets.
- Unauthorized scope options and pickers must not render.
- Theme tokens; mobile/tablet/desktop; no list-filter/pagination/Retry redesign; no unrelated refactoring.

## Acceptance Criteria

- Create dialog top scope is an actor-filtered radio group; segmented Entire organization / One facility controls are gone (Req 1).
- Platform needs no tenant/facility pickers; Tenant(s) and Facility(ies) show multi-select and require ≥1 target before identity fields enable (Req 2–3).
- Blocked identity fields show proactive guidance and reinforce it on focus/tap (Req 4).
- Save still runs similarity, refreshes the list, and opens details with Add permissions (Req 5).
- Widget tests cover radio visibility by actor, progressive pickers, guidance, and deferred permissions; backend tests cover platform/multi-target create contracts; `flutter analyze` and backend tests pass (Req 1–5).

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/role_mutation_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/shared/components/app_radio_group.dart`
- `backend/src/modules/role/services/role.service.js`
- `backend/src/modules/role/schemas/role.schema.js`
- `backend/src/lib/authorization/assignable-access.js`
- `screens/admin-setup/roles.md`
