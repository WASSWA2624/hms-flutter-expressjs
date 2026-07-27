# Fix role create similarity review and post-create navigation

## Objective

On `/admin/setup?section=roles`, require a separate similarity review before create, show accurate conflict/similarity detail, and open role details immediately after create or use-existing without flashing the roles list.

## Context

Create Role can show uniqueness failures as an inline “Update conflict” banner. Similarity review (`checkRoleDuplicates`, `showRoleSimilarityDialog`) exists but may skip when there are no matches, under-reports field-level similarity, and after create / use-existing the create dialog closes before details, briefly exposing the roles list. Mirror tenant similarity presentation depth. Inventory: `screens/admin-setup/roles.md`.

**Definitions:** **Create dialog** = create-mode `showRoleMutationDialog`. **Similarity review dialog** = separate `showRoleSimilarityDialog`. **Details dialog** = `_AccessAdminRoleDetailDialog`. **Overall similarity** = highest composite match score for the proposal; each match also shows composite % and `fieldComparisons` scores/statuses.

## Requirements

1. On Create Save, after client validation and before the create API call, always open the similarity review dialog—including when there are zero matches.
2. When matches or exact conflicts exist, list each role with composite %, overall similarity, and accurate per-field comparisons (name, display name, description, cross-identity) with status and %.
3. Do not show uniqueness/similarity as an inline create-dialog failure (including “Update conflict” / name-already-exists). Use the similarity review dialog only.
4. Similarity **Cancel** dismisses only that dialog and returns to the create dialog with values preserved; do not treat cancel as validation/conflict failure.
5. Allowed **Continue** / **Proceed** creates the role, then opens the details dialog for the new role.
6. **Use existing** opens details for the selected role without creating.
7. Exact name/display-name conflicts block Proceed; only Cancel or Use existing remain.
8. After create or use-existing, open details without a visible roles-list frame (continuous overlay; list reload may run silently).
9. Preserve loading, empty, error, success, and validation states; keep unauthorized create unrendered when `canWrite` is false.

## Constraints

Reuse `checkRoleDuplicates`, `fieldComparisons`, existing role dialogs/controllers/routes/l10n/design-system; align UI depth with tenant similarity without unrelated refactors. Backend RBAC/ABAC and uniqueness remain authoritative. Stay responsive on mobile/tablet/desktop; use theme tokens.

## Acceptance Criteria

- AC1: Create Save always opens similarity review before create API (Req 1).
- AC2: Matches/conflicts show composite %, overall similarity, and field-level %/status (Req 2).
- AC3: Uniqueness never appears as create-dialog “Update conflict” (Req 3).
- AC4: Cancel returns to preserved create form with no failure banner (Req 4).
- AC5: Allowed Proceed creates then opens new-role details (Req 5).
- AC6: Use existing opens that role’s details and does not create (Req 6).
- AC7: Exact conflicts disable Proceed (Req 7).
- AC8: No roles-list flash before details (Req 8).
- AC9: Unauthorized create unrendered; authorized create available (Req 9).

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_similarity_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_mutation_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/domain/entities/role_similarity.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_similarity_dialog.dart` (reference)
- `frontend/test/features/access_admin/domain/role_similarity_test.dart`
- `screens/admin-setup/roles.md`

## Verification

Extend `role_similarity_test.dart` for exact conflict, near-match, and field comparisons. Widget/integration: always-open review; cancel preserves create; proceed/use-existing open details; exact conflict blocks proceed; no create-dialog uniqueness banner; no list flash. Manual: duplicate, near-similar, and unique names; mobile/tablet/desktop; light/dark; unauthorized user never sees Create.
