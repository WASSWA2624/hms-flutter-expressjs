# Users, Roles, and Permissions Module — Implementation Prompt

## Objective

Complete **Users, Roles, and Permissions** administration for HOSSPI HMS so tenant and facility admins can manage staff access end-to-end: user accounts, role assignment, permission groups, action permissions, activation, demo accounts, and access scope — enabling correct RBAC/ABAC across all clinical and operational modules.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Users/roles row, Access Control Expectations
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 role/action rules (admin configures who may act)
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §13 role actions by admission desk, bed manager, nurse, doctor, etc.

**Central rule:** backend authorization is the source of truth; frontend mirrors permissions in `AccessGate` / `AppAccessActionGate`. This module administers assignments — individual modules only **request** permissions.

---

## Flow Integration Requirements

### OPD / IPD flows

| Concept | Access admin responsibility |
| ------- | --------------------------- |
| Role matrices | Ensure roles exist for reception, nurse, doctor, billing, lab, radiology, pharmacy per flow §5 / §13 |
| Module entitlements | Tie subscription module flags to role visibility ([prompts/26-subscriptions-module-prompt.md](./26-subscriptions-module-prompt.md)) |
| Multi-role users | Support users with more than one role per app-write-up |
| Scope | Tenant, facility, department, ward scope on assignments where applicable |

### App write-up — Access Control Expectations

- Every screen, menu, button, API call must respect role, permission, tenant scope, facility scope, and module entitlement.
- Frontend hiding is not enough — document that backend routes enforce auth.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Backend | `user`, `role`, `permission`, `role-assignment`, `module-entitlement` patterns | CRUD across modules |
| Frontend | **No dedicated feature folder** — settings workspace maps routes; UI largely unimplemented |
| Home | `manage_users_roles` action → settings/tenant routes | Navigation stub |
| HR | Staff profiles link to users | [prompts/14-hr-module-prompt.md](./14-hr-module-prompt.md) |
| Permissions client | `frontend/lib/core/permissions/` | Consumes session permissions |

### Known gaps

- No users/roles workspace UI (settings references unimplemented routes)
- No role assignment UI from HR staff profiles
- Demo account seeding documented in app-write-up but admin UI to view/reset missing
- Break-glass / elevated access not surfaced in admin UI if backend supports
- Audit of permission changes not in admin workspace

---

## Scope — Core Capabilities

1. **User directory** — search staff users; activate/deactivate; link to HR profile when exists.
2. **Role management** — assign/revoke roles; show effective permissions preview.
3. **Permission groups** — view action permissions; avoid editing system-critical roles without safeguards.
4. **Module entitlements** — show which modules user may access per subscription.
5. **Demo accounts** — list seeded demo users; reset passwords in non-production.

---

## Acceptance Criteria

- [ ] Admins can assign roles that unlock OPD/IPD actions per flow role tables.
- [ ] UI changes reflect in module menus and action gates after session refresh.
- [ ] Backend rejects unauthorized actions even if UI regresses.
- [ ] Tenant/facility scope enforced on user administration.

---

## Key File References

```
backend/src/modules/user/, role/, permission/
frontend/lib/core/permissions/
frontend/lib/features/settings/

Related prompts: prompts/23-tenant-facility-module-prompt.md, prompts/26-subscriptions-module-prompt.md, prompts/14-hr-module-prompt.md, prompts/27-settings-profile-module-prompt.md
```
