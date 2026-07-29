# UI Permission Scan — Discharge workspace / Pending clearance (`/discharge?…=pending-clearance`)

Deep-scan every UI atom on this tab (page chrome, list, row actions, detail, nested dialogs) and enforce permission-based visibility so users only see and use what their effective permissions allow.

## Context

- Target tab: **Pending clearance** (`pending-clearance`). Multi-department clearance; section gates per module rights.
- Feature code: `frontend/lib/features/discharge/`
- Module entitlement: `inpatient-bed-management`
- Route entry any-of: `clinical:read`, `clinical:write`, `pharmacy:read`, `billing:read`, `operations:read`
- Effective access = union(role/module/user grants) ∩ subscription ∩ ABAC (see `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `backend/src/config/permissions.js`).
- Reuse `AppAccessPolicy`, `AccessRequirement` (`allPermissions` = intersection, `anyPermissions` = union), `AppAccessGate` / `AppAccessActionGate`. Backend remains authoritative.
- Shared rules: `prompts/ui-permissions/_shared-rules.md`. Follow `prompts/.cursor/prompt.mdc` (structure, states, verification, AC↔requirement tracing).

## Permission matrix (HMS defaults for this tab)

| Concern | Semantics | Keys |
| --- | --- | --- |
| View / read UI | all-of (∩) | _(route/session gate only)_ |
| View / read UI | any-of (∪) | `clinical:read`, `pharmacy:read`, `billing:read`, `operations:read`, `last_office:read` |
| Create | all-of (∩) | `clinical:write` |
| Update | all-of (∩) | `clinical:write` |
| Delete | all-of (∩) | `clinical:write` |
| Nested cross-module read | any-of (∪) | _(n/a)_ |
| Nested cross-module write | any-of (∪) | _(n/a)_ |
| Nested cross-module write | all-of (∩) | _(n/a)_ |

Planning/clearance writes need clinical:write. Clearance checklist sections: pharmacy:read for meds, billing:read for bills, operations:read for room turnover—show section only when that right is held (union across sections, intersection within section).

Prefer existing feature `*Requirement` helpers when present; align them to this matrix rather than inventing a second vocabulary. Adjust only when source already documents a different gate—then keep source and note the mapping in tests.

## Requirements

1. Inventory every visible atom on this tab from the presentation source: tab-strip actions for this section, search/filters/columns, summary chips, rows, next-actions, empty/error/retry, detail sheets, and every nested dialog/workflow reachable from this tab only.
2. Classify each atom as read, create, update, delete, approve, export, navigate, or progressive-disclosure chrome; map it to exact `AppPermissions` keys using the matrix (intersection vs union as specified).
3. Gate rendering with `grantsAll` / `grantsAny` / `AccessRequirement.isAllowed` before build; unauthorized controls, data-only columns/panels, and nested write entry points must not mount. Do not use disabled/grey unauthorized controls or routine "no access" banners; forbidden feedback only for restricted deep links, stale permissions, or backend `403`.
4. Apply subscription module entitlements and ABAC scope (tenant/facility/ward/assignment/own) after RBAC; strip UI the plan or scope forbids even if a role pack includes the permission string.
5. Preserve authorized UI states on this tab: permission-filtered chrome, loading, empty, error/retry, success, validation, and visible feedback (e.g. snackbar). After successful mutations, synchronize lists/detail.
6. Collapse empty sections when all children are filtered; hide the tab from the strip when the user fails the tab's read requirement if the screen supports per-tab gates; otherwise keep the strip but show only authorized content.
7. Add/update widget/unit tests in `frontend/test/` proving: (a) missing any required intersection permission => atom absent; (b) full intersection set => atom present; (c) union grants show the union of allowed atoms when the matrix uses union; (d) nested cross-module UI absent without those rights; (e) authorized flows still succeed. Cover integration with existing gates/routes, reuse of feature `*Requirement` helpers, authorization, post-mutation sync, UI states, one mobile and one desktop viewport, and light + dark themes.

## Constraints

- Scope: this tab's UI tree and nested dialogs opened from it only; do not redesign unrelated screens.
- Reuse `AppAccessPolicy`, `AccessRequirement`, `AppAccessGate` / `AppAccessActionGate`, design-system components, routes, and feature `*Requirement` helpers; no second permission vocabulary.
- Theme tokens; responsive mobile/tablet/desktop without clipping, overflow, duplication, or inaccessible actions; light and dark.
- Backend RBAC/ABAC remains authoritative; no exploit/PoC code; no secrets in tests—use policy fixtures.
- Optional enhancements: none. Do not expand beyond this tab's permission enforcement.

## Acceptance Criteria

- AC1 (Req 1-2): Every actionable atom on this tab has an explicit permission mapping from the inventory and matrix.
- AC2 (Req 3): Denied atoms (controls, data-only columns/panels, nested write entry points) do not render; no disabled unauthorized affordances or routine "no access" banners.
- AC3 (Req 2-3): Create/update/delete/approve/export controls match the matrix verbs; read-only users cannot mutate.
- AC4 (Req 3-4): Intersection and union behave as specified; subscription/ABAC strips UI that role packs alone would allow; cross-module nested UI respects nested matrix rows.
- AC5 (Req 5-6): Loading, empty, error, success, validation, and visible-feedback states remain observable for authorized users; filtered sections/tabs collapse; frontend data synchronizes after mutations.
- AC6 (Req 7): Tests in `frontend/test/` prove unauthorized absence and authorized presence (including at least one intersection denial and one union allowance when the matrix uses both) and cover integration, reuse, authorization, sync, UI states, representative viewports, and light/dark.

## Relevant Files

- `frontend/lib/features/discharge/`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/core/permissions/access_requirement.dart`
- `frontend/lib/core/permissions/access_gate.dart`
- `frontend/lib/app/router/app_routes.dart`
- `prompts/ui-permissions/_shared-rules.md`
- `prompts/.cursor/prompt.mdc`
- `.cursor/access/permissions.mdc`
- `frontend/.cursor/permissions.mdc`
- `backend/src/config/permissions.js`
- Matching `frontend/test/features/...` for this workspace
