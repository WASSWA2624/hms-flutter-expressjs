# UI Permission Enforcement — Shared Rules

Canonical rules for every prompt under `prompts/ui-permissions/`. Tab prompts refine matrices; they must not contradict this file or `prompts/.cursor/prompt.mdc`.

## Objective

Users must only see and use UI that their **effective** permissions allow. Backend authorization remains authoritative; frontend hiding prevents leakage and dead ends.

## Effective access

```
effective = union(role grants, module grants, user grants)
          ∩ subscription package modules
          ∩ plan permission caps
          ∩ ABAC scope (tenant, facility, ward/unit, assignment, own)
```

- **Intersection (∩ / `allPermissions` / `grantsAll`)**: every listed key required (e.g. payment gate needs `patient:read` and `billing:read`).
- **Union (∪ / `anyPermissions` / `grantsAny`)**: any one key sufficient (e.g. route entry via `clinical:read` or `operations:read`).
- Multi-role users receive the **union** of grants, then ∩ subscription/ABAC. Never unlock excluded modules via role packs alone.

## CRUD mapping (HMS)

| UI intent | Typical permission verb |
| --- | --- |
| View lists, detail, KPIs, reports | `*:read` |
| Register, schedule, create order/request | `*:write` or module `request` |
| Edit demographics, update stage, amend | `*:write` / `*:update` |
| Soft/hard delete, void, revoke | `*:delete` (or write only if product has no delete key) |
| Approve claims, roster, mortuary, financial | `*:approve` / `financial:approve` / `roster:approve` |
| Export evidence/reports | `*:export` / `evidence:export` / `reports:read` |

Use exact `AppPermissions` keys from `access_policy.dart` / `backend/src/config/permissions.js`.

## Enforcement UX

- Unauthorized UI **must not render** (no disabled stubs, no routine “no access” copy).
- Forbidden feedback only for direct restricted deep links, stale permissions, or backend `403`.
- Hide tabs/sections when the user fails that surface’s read requirement and the screen supports per-section gates.
- Nested dialogs inherit parent gates and add their own; never open a write dialog for a read-only user via a leftover icon.

## Implementation reuse

- Prefer existing `*Requirement` / `AppAccessGate` / `AppAccessActionGate` helpers.
- Filter lists of actions/chips/columns with shared helpers (see home dashboard atom permissions pattern).
- Keep loading, empty, error/retry, success, validation states for authorized paths.
- Synchronize frontend data after successful mutations.

## Verification (every tab prompt)

Widget/unit tests must prove unauthorized absence and authorized presence for representative atoms, including at least one ∩ denial and one ∪ allowance case where the matrix uses both.

## Related

- `.cursor/access/permissions.mdc`, `modules.mdc`, `subscriptions.mdc`, `default_user_roles.mdc`
- `frontend/.cursor/permissions.mdc`
- `prompts/.cursor/prompt.mdc`

