# Authorization & Security — Implementation Prompt

## Objective

Build and enforce a secure authorization model across backend APIs, realtime subscriptions, and the Flutter UI so effective access is always:

`union(role, module, and direct-user grants) ∩ active subscription permissions ∩ assigned modules ∩ ABAC scope`

**Source requirement:** [prompt.md](../prompt.md) §1  
**Also required:** [prompts/00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md)

---

## Mandatory reading

1. [`.cursor/access/modules.mdc`](../.cursor/access/modules.mdc)
2. [`.cursor/access/permissions.mdc`](../.cursor/access/permissions.mdc)
3. [`.cursor/access/subscriptions.mdc`](../.cursor/access/subscriptions.mdc)
4. [`.cursor/access/default_user_roles.mdc`](../.cursor/access/default_user_roles.mdc)
5. [`backend/.cursor/auth-security.mdc`](../backend/.cursor/auth-security.mdc)
6. [`frontend/.cursor/permissions.mdc`](../frontend/.cursor/permissions.mdc), [`security.mdc`](../frontend/.cursor/security.mdc), [`authentication_session.mdc`](../frontend/.cursor/authentication_session.mdc), [`scope.mdc`](../frontend/.cursor/scope.mdc)

---

## Pre-implementation audit

- Map current RBAC/ABAC middleware, permission catalogs, subscription checks, break-glass paths, and frontend `AccessGate`/route guards.
- Identify endpoints, reports, exports, WebSocket subscriptions, and UI actions that skip backend enforcement or render unauthorized controls.
- Note any grants that can exceed active subscription or contextual scope.

---

## Step-by-step instructions

### 1. Backend as source of truth

- Enforce authorization on every API operation, record, workflow transition, report, export, and realtime subscription.
- Apply ABAC at tenant, facility, department, unit, ward, room, bed, encounter, ownership, and action level as applicable.
- Frontend guards and visibility must mirror backend decisions — never replace them.
- Reject unauthorized requests without leaking PHI or record existence.

### 2. Effective access calculation

- Support multiple roles and module assignments per user.
- Compute effective permissions as the intersection formula above.
- No grant (role, module, or direct) may exceed active subscription or contextual scope.

### 3. Default catalogs

- Keep a complete source-controlled catalog of modules, subscription packages, roles, and permissions under `.cursor/access/` and matching seed/migration data.
- Admin customize/restore-defaults must be atomic, versioned, and audited.
- Seed/migration changes: preserve valid assignments; remove obsolete permission rows only after replacement is verified.

### 4. Break-glass

- Break-glass access must be explicit, justified, time-limited, narrowly scoped, fully audited, and online-only.
- Expire and revoke automatically; never silently extend.

### 5. Session & context isolation (frontend + backend)

On logout, account switch, or tenant/facility context change, immediately dispose of:

- Authenticated providers and in-memory state
- Local database partitions and user-specific caches
- Pending requests and realtime subscriptions

Additional rules:

- Partition persisted non-sensitive state by user + tenant/facility.
- Credentials only in secure storage; never persist PHI in insecure preferences.
- Neutral loading during session restore/context switch — never flash previous-context data.
- Dashboards, pages, badges, exports, and shared components read only current authorized scope.

### 6. UI visibility rules

- Do not render unauthorized pages, routes, nav items, buttons, dialogs, fields, data, or workflow actions.
- Disable only when the user is authorized but a prerequisite or workflow state blocks the action.

### 7. Database / migrations (if schema gaps)

- Align permission/role/module/subscription tables with the access catalogs.
- Safe migrations + backfills; rollback notes; remove obsolete columns/tables/code after verified cutover.

---

## Tests (required)

- Cross-user, cross-tenant, cross-facility isolation
- Expired subscription and revoked permission
- Account-switch / context-switch isolation (no data flash)
- Break-glass expiry and audit trail
- Frontend hide vs disable behavior matches backend

## Related prompts

- [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md)
- [06-permission-aware-actions.md](./06-permission-aware-actions.md)
- [13-general-application-consistency.md](./13-general-application-consistency.md)
