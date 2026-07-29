# UI Permission Enforcement — Shared Rules

Canonical rules for every prompt under `prompts/ui-permissions/`. Tab prompts refine matrices; they must not contradict this file or `prompts/.cursor/prompt.mdc`.

## Prompt compliance (`prompts/.cursor/prompt.mdc`)

Every tab prompt must:

- Stay under 1001 words; begin with an H1 and a one-sentence objective.
- Include `Context`, `Requirements`, `Constraints`, `Acceptance Criteria`, and `Relevant Files`.
- Number requirements; make acceptance criteria observable and trace each to numbered requirements (e.g. `AC2 (Req 3)`).
- Use imperative language; define ∩ / ∪ / effective access once here—tab prompts reference this file instead of restating it.
- Separate optional work: tab prompts must state `Optional enhancements: none` unless a tab truly needs a named, non-blocking enhancement.
- Name permission, loading, empty, error, success, validation, and visible-feedback states for authorized paths.
- Name verification: widget/unit tests plus checks for integration, reuse, authorization, synchronization, UI states, representative viewports, and light/dark themes.

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

- Unauthorized UI **must not render** (no disabled stubs, no routine “no access” copy). Prefer absence over “hide/disable” wording when they conflict.
- Forbidden feedback only for direct restricted deep links, stale permissions, or backend `403`.
- Hide tabs/sections when the user fails that surface’s read requirement and the screen supports per-section gates.
- Nested dialogs inherit parent gates and add their own; never open a write dialog for a read-only user via a leftover icon.

## Implementation reuse

- Prefer existing `*Requirement` / `AppAccessGate` / `AppAccessActionGate` helpers.
- Filter lists of actions/chips/columns with shared helpers (see home dashboard atom permissions pattern).
- Keep loading, empty, error/retry, success, validation, and visible-feedback states for authorized paths.
- Synchronize frontend data after successful mutations.
- Keep layouts responsive on mobile, tablet, and desktop; use theme tokens for light and dark.

## Screen inventories

- The former `screens/` inventory folder has been removed.
- Do **not** recreate `screens/` or write inventory markdown there.
- Inventory atoms from feature presentation code, routes, and tests.

## Verification (every tab prompt)

Widget/unit tests must prove unauthorized absence and authorized presence for representative atoms, including at least one ∩ denial and one ∪ allowance case where the matrix uses both. Verification must also cover:

- Integration with existing gates/routes
- Reuse of feature `*Requirement` helpers (no second vocabulary)
- Authorization (RBAC ∩ subscription ∩ ABAC)
- Post-mutation synchronization
- Authorized UI states listed above
- Representative mobile and desktop viewports
- Light and dark themes

## Related

- `.cursor/access/permissions.mdc`, `modules.mdc`, `subscriptions.mdc`, `default_user_roles.mdc`
- `frontend/.cursor/permissions.mdc`
- `prompts/.cursor/prompt.mdc`
- `backend/src/config/permissions.js`
