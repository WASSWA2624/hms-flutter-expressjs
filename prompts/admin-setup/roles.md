# Fix create-role similarity, create commit, and details handoff

Make **Create role** on `/admin/setup?section=roles` run accurate scoped similarity review, create when allowed, and open role details afterward.

## Context

- Inventory: `screens/admin-setup/roles.md`. Create uses Scope (**Platform** / **Tenant(s)** / **Facility(ies)**) plus Role name, Display name, optional Description, then **Save**.
- Create always opens `showRoleSimilarityDialog` before the create API. Engines: FE `checkRoleDuplicates`, `_loadRoleSimilarityPeers`; BE `assertRoleUniqueness`, `confirm_similar`.
- Repro: list has `Testing` (Organization and Facility · DemoCare); creating Platform `Testing`/`Testing`/`Testing` shows **No similar found** / **0%**. **Continue create** reopens the same empty review—role is not saved and details never open.
- **Definitions:** Peer set = roles loaded for scoring. Exact same-scope name/display conflict blocks proceed. Near/cross-scope identity matches warn and stay overridable via confirm.

## Requirements

1. Fix false negatives: when same or near-same name and/or display name (description when set) exist among roles the actor can load, review must list them with a non-zero top overall score—not **No similar found** / **0%**.
2. Peer load must be scope-correct: Platform → all roles; Tenant → all org/facility roles in that tenant (not facility-narrowed); Facility → peers BE already uses for scoring. Respect `ROLE_SIMILARITY_LOOKUP_LIMIT` / page ceiling; keep lean DTO scoring fields. Failed peer lookup must error—never empty “no similar.”
3. Keep FE/BE scoring aligned (name, display_name, description, cross_identity). Surface cross-scope identity matches; do not hide them as zero matches.
4. Allowed **Continue create** must create once with `confirm_similar` when required, persist, close review+create, and not reopen empty “no similar” for the same draft. Exact same-scope conflicts disable proceed (**Cancel** / **Use existing** only).
5. After successful create or **Use existing**, open `_AccessAdminRoleDetailDialog` (edit, delete, attach permissions) without a roles-list flash; silently refresh the list.
6. Preserve loading, empty, error, validation, success, and review states; keep unauthorized create unrendered when `canWrite` is false.

## Constraints

Reuse existing role similarity modules, dialogs, controllers, routes, l10n, and design-system components; no unrelated refactors. Backend RBAC/ABAC and uniqueness remain authoritative. Stay responsive on mobile/tablet/desktop; use theme tokens for light and dark.

## Acceptance Criteria

- AC1: With visible `Testing` roles, creating `Testing` shows matches (not **No similar found** / **0%**). → 1–3
- AC2: Allowed **Continue create** creates once and does not loop empty review. → 4
- AC3: Exact same-scope conflict blocks proceed; near match proceeds only after confirm. → 3–4
- AC4: Create / Use existing opens role details without list flash; list syncs. → 5
- AC5: Unauthorized create unrendered; authorized create available. → 6

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_similarity_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/domain/entities/role_similarity.dart`
- `backend/src/lib/role/role-similarity.js`
- `backend/src/modules/role/services/role.service.js`
- `frontend/test/features/access_admin/domain/role_similarity_test.dart`
- `frontend/test/features/access_admin/presentation/role_create_similarity_flow_test.dart`
- `backend/src/tests/lib/role/role-similarity.test.js`
- `screens/admin-setup/roles.md`

## Verification

- Unit: FE/BE duplicates for exact, near, cross-scope identity, and peer-load false-empty repro.
- Flow: always-open review; failed peer lookup errors; **Continue create** creates once; conflict reopens review only with real matches; details handoff + silent reload.
- Manual: Create `Testing` while Organization/Facility `Testing` exist → matches; unique name → create → details; Cancel preserves form; dark/light; narrow viewport.
