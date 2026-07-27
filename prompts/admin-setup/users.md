# Defer Create User roles/permissions; add similarity and details handoff

Make **Create user** on `/admin/setup?section=users` capture Organization + User details only, run scored similarity review before persist, then open User Details for roles and direct permissions.

## Context

- Inventory: `screens/admin-setup/users.md`. Create opens `showUserMutationDialog` in **Create** mode when `canWrite`.
- Current form: Organization (tenant *, facility *), User details (Email *, Phone, Position title *, Status, Password ≥8), plus Assigned roles and Direct permissions. Submit uses `createUserWithRoles` / `permission_ids`; no similarity review; details do not open after create.
- Role create defers permissions, runs similarity review, and opens details—reuse it.
- **Definitions:** Organization = tenant + facility. Similarity review = scored peer dialog before create. Exact conflict blocks proceed; near matches need `confirm_similar`. Roles/direct permissions assigned only from `_AccessAdminUserDetailDialog`.

## Requirements

1. Keep **Create user** opening Create-mode mutation dialog when `canWrite`; Cancel/close discards without save.
2. Show Organization pickers by actor only: platform admins pick tenant then facility; tenant actors get tenant fixed and pick facility; facility-locked actors get both fixed (unauthorized pickers unrendered). Do not load roles/permissions catalogs for create. Preserve loading, empty, retry, and scope banners.
3. Keep User details: required Email and Position title; optional Phone; Status (default ACTIVE); Password required on create (≥8). Omit Assigned roles and Direct permissions; do not submit `roleIds` / `permission_ids` on create.
4. On Create Save, always open user similarity review before create. Score peers on all submitted identity fields (email, phone, position title, other uniqueness fields). Exact conflicts: Cancel / Use existing only. Near matches: Continue create with `confirm_similar`. Failed peer lookup must error—never empty “no similar.” Reuse role/tenant similarity UI and contracts.
5. After successful create or Use existing, close review + create, open `_AccessAdminUserDetailDialog` without a list flash, and silently refresh the list. Manage roles/direct permissions only from details.
6. Preserve validation, loading, empty, error, success, and unauthorized states; unauthorized create unrendered when `canWrite` is false.

## Constraints

Reuse access-admin dialogs, controllers, repositories, role/tenant similarity review UX, l10n, and design-system components; extend user draft/API with `confirm_similar` and a user-similarity helper as needed. Backend RBAC/ABAC remains authoritative. Stay responsive; theme tokens for light/dark. No unrelated list-filter/pagination refactors.

## Acceptance Criteria

- AC1: Create shows Organization + User details only; roles/permissions sections absent; unauthorized scope pickers unrendered. → 1–3
- AC2: Create Save opens scored similarity review; exact conflict blocks; near match needs confirm; peer-load failure errors. → 4
- AC3: Allowed Continue create persists once with `confirm_similar` when required and does not loop empty review. → 4–5
- AC4: Create / Use existing opens User Details without list flash; list syncs; roles/permissions only from details. → 5
- AC5: Unauthorized create unrendered; authorized create available; validation and load/empty/error states preserved. → 2, 6

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/user_mutation_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_similarity_dialog.dart`
- `backend/src/modules/user/services/user.service.js`
- `screens/admin-setup/users.md`

## Verification

- Unit/flow: create omits roles/permission_ids; similarity exact/near/confirm; peer-load failure; details handoff + silent reload; unauthorized create absent.
- Manual: Create → no roles/permissions → review → details; Cancel preserves form; dark/light; narrow.