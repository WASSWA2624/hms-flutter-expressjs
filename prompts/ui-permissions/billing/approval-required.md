# UI Permission Scan — Billing workspace / Approval required (`/billing?…=approval-required`)

Deep-scan every UI atom on this tab (page chrome, list, row actions, detail, nested dialogs) and enforce permission-based visibility so users only see and use what their effective permissions allow.

## Context

- Screen inventory: `screens/billing.md` (source of truth for reachable controls).
- Target tab: **Approval required** (`approval-required`). Approve/reject financial holds.
- Feature code: `frontend/lib/features/billing/`
- Module entitlement: `billing-payments`
- Route entry any-of: `billing:read`, `billing:write`
- Effective access = union(role/module/user grants) ∩ subscription ∩ ABAC (see `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`).
- Reuse `AppAccessPolicy`, `AccessRequirement` (`allPermissions` = intersection, `anyPermissions` = union), `AppAccessGate` / action gates. Backend remains authoritative.
- Shared rules: `prompts/ui-permissions/_shared-rules.md`. Follow `prompts/.cursor/prompt.mdc`.

## Permission matrix (HMS defaults for this tab)

| Concern | Semantics | Keys |
| --- | --- | --- |
| View / read UI | all-of (∩) | `billing:read` |
| View / read UI | any-of (∪) | _(n/a)_ |
| Create | all-of (∩) | `financial:approve` |
| Update | all-of (∩) | `financial:approve` |
| Delete | all-of (∩) | `billing:write` |
| Nested cross-module read | any-of (∪) | _(n/a)_ |
| Nested cross-module write | any-of (∪) | _(n/a)_ |
| Nested cross-module write | all-of (∩) | `billing:write` |

Close shift/day need billing:write. Approval-required mutations need financial:approve (intersection with billing:write when both apply). Claims-pending may deep-link to claims; hide if insurance module / billing rights missing.

Prefer existing feature `*Requirement` helpers when present; align them to this matrix rather than inventing a second vocabulary. Adjust only when source already documents a different gate—then keep source and note the mapping in tests.

## Requirements

1. Inventory every visible atom on this tab from presentation source: tab strip actions for this section, search/filters/columns, summary chips, rows, next-actions, empty/error/retry, detail sheets, and every nested dialog/workflow reachable from this tab only.
2. Classify each atom as read, create, update, delete, approve, export, navigate, or progressive-disclosure chrome; map it to `AppPermissions` using the matrix (intersection vs union as specified).
3. Gate rendering with `grantsAll` / `grantsAny` / `AccessRequirement.isAllowed` before build; unauthorized controls, columns that solely expose forbidden data, and unauthorized nested actions must not mount. Do not use disabled/grey unauthorized controls or routine “no access” banners.
4. Apply plan module entitlements and ABAC scope (tenant/facility/ward/assignment/own) after RBAC; strip UI the plan or scope forbids even if a role pack includes the permission string.
5. Keep authorized UX intact: loading, empty, error/retry, success/snackbar, and validation states must still work for permitted users; after mutations, synchronize lists/detail.
6. Collapse empty sections when all children are filtered; hide the tab itself from the strip when the user cannot meet the tab’s read requirement (if the screen already supports per-tab requirements; otherwise keep strip but empty-authorized content only).
7. Add/update widget tests proving: (a) missing any required ∩ permission ⇒ atom absent; (b) holding the full ∩ set ⇒ atom present; (c) ∪ grants show the union of allowed atoms; (d) nested cross-module chips absent without those rights; (e) authorized flows still succeed.

## Constraints

- Scope: this tab’s UI tree and nested dialogs opened from it; do not redesign unrelated screens.
- Reuse design-system components and existing gates; no second permission vocabulary.
- Theme tokens; responsive mobile/tablet/desktop; light and dark.
- No exploit/PoC code; no secrets in tests—use policy fixtures.

## Acceptance Criteria

- Every actionable atom on this tab has an explicit permission mapping and is absent when denied.
- Create/update/delete/approve/export controls match the matrix verbs; read-only users cannot mutate.
- Intersection and union behave as specified; cross-module nested UI respects nested rows.
- Unauthorized data-only columns/panels do not render; no disabled unauthorized affordances.
- Tests in `frontend/test/` cover denial and allowance fixtures for this tab’s critical atoms.
- Loading/empty/error/success remain observable for authorized users.

## Relevant Files

- `screens/billing.md`
- `frontend/lib/features/billing/`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/core/permissions/access_requirement.dart`
- `frontend/lib/core/permissions/access_gate.dart`
- `frontend/lib/app/router/app_routes.dart`
- `prompts/ui-permissions/_shared-rules.md`
- Matching `frontend/test/features/...` for this workspace
