# Fix create-role similarity false negatives

Ensure **Create role** similarity review on `/admin/setup?section=roles` detects existing similar roles and never reports **No similar found** / **0%** when matching identity already exists among roles the actor can see.

## Context

- Platform admin opens **Create role**, chooses Scope (**Platform** / **Tenant(s)** / **Facility(ies)**), enters Role name, Display name, optional Description, then **Save**.
- Create always opens the similarity dialog before the create API.
- Bug: name/display `Testing` → **No similar found** and **0%**, while the Roles list already shows `Testing` (Organization and Facility · DemoCare).
- Engines: FE `checkRoleDuplicates`, `_loadRoleSimilarityPeers`, `showRoleSimilarityDialog`; BE `assertRoleUniqueness`, `ROLE_SIMILARITY_LOOKUP_LIMIT`, `confirm_similar`. Scoring uses name, display name, description, cross-identity, and `roleScopesMatch`.

## Requirements

1. Fix the false-negative path: when same or near-same name and/or display name (and description when set) already exists in roles the actor can load, Create must show those matches with a non-zero top overall score—not **No similar found** / **0%**.
2. Review peer loading and filtering (FE lean page size vs BE lookup limit, tenant/facility filters, `roleScopesMatch`, lean DTO fields). Do not drop peers needed for scoring before compare.
3. Score all defined identity signals (name, display_name, description, cross_identity, aliases, filler stripping, token variants). Keep FE and BE rules aligned.
4. Same-scope exact name/display conflicts block proceed; near matches stay overridable via confirm / `confirm_similar`. Surface cross-scope identity matches in review when they exist; do not hide them as zero matches.
5. Keep Create actions: **Cancel**, **Use existing**, **Continue create** when allowed; edit must exclude self.
6. After successful create, refresh the Roles list; do not render unauthorized create.

## Constraints

- Reuse existing role similarity modules, dialogs, validation, RBAC/ABAC, and design-system components; no unrelated refactors.
- Backend remains authoritative for uniqueness and `confirm_similar`.
- Cover loading, empty, error, validation, success, and similarity review; stay responsive across viewports and themes.

## Acceptance Criteria

- AC1: With visible `Testing` roles, creating `Testing`/`Testing` shows matches (not **No similar found** / **0%**). → 1–4
- AC2: Exact same-scope conflict blocks proceed; near match proceeds only after confirm. → 4–5
- AC3: FE/BE tests cover the repro, peer inclusion, field/cross-identity scoring, and create flow. → 1–5
- AC4: Authorized create remains; unauthorized create UI is absent. → 6

## Relevant Files

- `frontend/lib/features/access_admin/domain/entities/role_similarity.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_similarity_dialog.dart`
- `backend/src/lib/role/role-similarity.js`
- `backend/src/modules/role/services/role.service.js`
- `frontend/test/features/access_admin/domain/role_similarity_test.dart`
- `frontend/test/features/access_admin/presentation/role_create_similarity_flow_test.dart`
- `backend/src/tests/lib/role/role-similarity.test.js`
- `screens/admin-setup/roles.md`

## Verification

- Unit: FE/BE duplicates for exact, near, cross-identity, and the `Testing` false-empty repro (peer-load/scope).
- Flow: create always opens review; uniqueness conflict reopens review; `confirm_similar`.
- Manual: platform admin Create `Testing` while Organization/Facility `Testing` exist → matches shown; Cancel / Use existing / Continue create; list sync; dark/light; narrow viewport.
