# Clarify User Details Hierarchy, Account Layout, and Access Panels

On `/admin/setup?section=users`, refine `_AccessAdminUserDetailDialog` so identity, Account, Assigned roles, and Direct permissions are scannable and easy to manage—without changing mutation contracts.

## Context

- Inventory: `screens/admin-setup/users.md`. Row select opens `_AccessAdminUserDetailDialog` (summary, Account, `AppUserAccessPanel`).
- Summary often leads with email as `item.title`, then position and email again plus ID/status/role-count chips—hierarchy is unclear.
- Account lists ID, email, phone, position, tenant, facility in a responsive grid; values duplicate the summary.
- Assigned roles: Add/Remove work; inherited permissions render as an always-expanded chip cloud. Role permissions are read-only. Direct permissions already support Add and per-row Remove when `canWrite`.
- **Definitions:** Role permission = inherited (not individually removable). Direct permission = user-level grant (individually removable).

## Requirements

1. Lead the summary with one primary identity (prefer display name/position when distinct from email; otherwise email once), then secondary contact and chips for ID, status, and role count—do not repeat the same email as title and body.
2. Keep Account labeled and icon-aligned in one or two columns by viewport; omit empty fields; reduce summary redundancy without dropping present ID, phone, email, position, tenant, or facility.
3. Keep **Add role** / **Remove role** when `canWrite` and not soft-deleted—one remove control per removable role. Inherited permissions stay display-only; use progressive disclosure (collapsed count; expand to chips) so large sets do not dominate by default.
4. Keep **Add permission** and per-item **Remove** for direct permissions when `canWrite`. Empty state prefers assigning a role. Removing a direct permission must not revoke role grants.
5. Preserve footer Edit / Activate|Deactivate / Delete (when allowed) / Close, busy disablement, demo/system-critical banners, unauthorized controls unrendered when `!canWrite`, and post-mutation detail + list sync.
6. Update `screens/admin-setup/users.md` for Add/Remove role, Add/Remove direct permission, and Activate/Deactivate.

## Constraints

Reuse `_AccessAdminUserDetailDialog`, `AppUserAccessPanel`, assign/revoke/sync APIs, l10n, and design-system components; no unrelated refactors. Backend RBAC/ABAC authoritative. Theme tokens; light/dark; responsive without overflow.

## Acceptance Criteria

- AC1: Summary has one primary identity and non-duplicative contact + chips. → 1
- AC2: Account complete for present fields, organized, less redundant on narrow/wide. → 2
- AC3: Add/Remove role work; inherited permissions collapse with count and expand on demand; cannot remove one role permission. → 3
- AC4: Direct permissions add/remove one-by-one; empty prefers roles; role grants unaffected. → 4
- AC5: Footer, banners, busy, unauthorized absence, and sync behavior unchanged. → 5
- AC6: Screens inventory lists access and status actions. → 6

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/shared/components/app_user_access_panel.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/access_admin/presentation/users_setup_scope_flow_test.dart`
- `screens/admin-setup/users.md`

## Verification

- Flow/unit: add/remove role; expand/collapse role permissions; add/remove direct permission; unauthorized actions absent.
- Manual: user with many role permissions starts collapsed; summary/Account readable on mobile/desktop; light/dark; footer actions still work.
