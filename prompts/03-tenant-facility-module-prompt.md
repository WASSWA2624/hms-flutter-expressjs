# Tenant and Facility Settings Module — Implementation Prompt

## Objective

Complete **Tenant and Facility Settings** for HOSSPI HMS so platform, tenant, and facility admins can configure the hospital organization end-to-end: tenant profile, facilities, branches, departments, units, contacts, addresses, and the **ward/room/bed catalog** that downstream clinical modules consume.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Tenant settings, Facility settings, Rooms/wards/beds boundaries
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §3 ward/bed classes used at admission (consume config, do not redefine)
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — service units and provider context consume facility structure

**Central rule:** organizational structure is defined **once** here. OPD, IPD, Nursing, and Rooms/Beds modules **consume** ward/bed/department IDs — they must not maintain parallel facility masters.

---

## Flow Integration Requirements

### IPD / OPD (indirect)

| Flow concept | Tenant/facility responsibility |
| ------------ | ---------------------------- |
| Ward/bed classes | Configure wards, rooms, beds with types (ICU, isolation, etc.) |
| Departments/units | Service points for OPD routing and IPD consultant assignment |
| Facility scope | All CRUD respects tenant/facility scope from session |

### App write-up (`../.cursor/app-write-up.mdc`)

| Module row | This module owns |
| ---------- | ---------------- |
| Tenant settings | Tenant profile, subscription relationship, enabled modules, tenant admins |
| Facility settings | Facility identity, branches, departments, units, wards, beds, defaults |
| Rooms, wards, beds | Physical structure — operational bed board is [prompts/05-rooms-beds-module-prompt.md](./05-rooms-beds-module-prompt.md) |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/tenant_facility/` | `tenant_facility_setup_page.dart`, repository, catalog panels |
| Backend | `tenant`, `facility`, `branch`, `department`, `unit`, `ward`, `room`, `bed`, `contact`, `address` | Granular CRUD |
| Auth bootstrap | Registration may seed default tenant/facility | See [prompts/01-auth-module-prompt.md](./01-auth-module-prompt.md) |
| Settings hub | Routes to tenant_facility for catalog sections | [prompts/06-settings-profile-module-prompt.md](./06-settings-profile-module-prompt.md) |

### Known gaps

- No backend `tenant-facility-workspace` aggregator — client composes many calls
- Users/roles admin not in this feature ([prompts/04-access-admin-module-prompt.md](./04-access-admin-module-prompt.md))
- Large monolithic setup page — split by entity or wizard steps
- Facility clinical catalog (diagnoses, procedures) partially in shared clinical catalog UI
- Validation gaps on optional branch/department fields

---

## Scope — Core Capabilities

1. **Tenant profile** — name, contacts, subscription visibility (read link to subscriptions).
2. **Facility identity** — logo, address, contacts, branches.
3. **Organizational tree** — departments, units, service points.
4. **Care spaces** — wards, rooms, beds with types and active flags.
5. **Guided setup** — main setup flow steps 1–4 from app-write-up Main Setup Flow.

---

## Acceptance Criteria

- [ ] Admins can configure tenant and facility hierarchy end-to-end.
- [ ] Wards/beds created here appear in IPD and rooms_beds modules.
- [ ] No duplicate structure definitions in clinical modules.
- [ ] Tenant/facility scope enforced on all mutations.

---

## Key File References

```
frontend/lib/features/tenant_facility/
backend/src/modules/tenant/, facility/, ward/, room/, bed/

Related prompts: prompts/05-rooms-beds-module-prompt.md, prompts/02-subscriptions-module-prompt.md, prompts/04-access-admin-module-prompt.md
```
