# Demo and Seed Data Module — Implementation Prompt

## Objective

Document and maintain **Demo and Seed Data** for HOSSPI HMS: safe, repeatable seeding for development, testing, onboarding, and product demonstrations — covering tenant, facility, users, roles, subscriptions, modules, patients, and sample clinical/operational records per [app-write-up.mdc](../.cursor/app-write-up.mdc) Demo and Seed Data Expectations.

**Scope:** Backend seed scripts, idempotent demo markers, environment guards (never accidental production seed), and alignment with OPD/IPD demo flows.

**Central rule:** all seed data must be **clearly marked as demo**, safe to clear/recreate, and **disabled in production** unless explicitly overridden with strong safeguards.

---

## Flow Integration Requirements

### Main Setup Flow (app-write-up)

Seed must support steps 1–7:

1. Default tenant and facility
2. Facility structure (departments, wards, beds, service units)
3. Default admins and department demo users (doctor, nurse, receptionist, cashier, pharmacist, lab, radiology, HR, operations, housekeeping, mortuary, etc.)
4. Roles, permissions, module entitlements
5. Subscription plan, active subscription, module subscriptions, license
6. Sample patients and visits through **OPD → triage → clinical → lab/pharmacy → billing**
7. Sample **IPD admissions**, nursing, discharge, and operational records (operations, biomedical, mortuary)

### OPD flow

- Sample OPD encounters in various backend stages (`WAITING_VITALS`, `WAITING_DOCTOR_REVIEW`, `LAB_REQUESTED`, `DISCHARGED`, `ADMITTED`).
- At least one patient ready for OPD-to-IPD handoff testing.

### IPD flow

- Admissions in `ADMITTED_PENDING_BED`, `ADMITTED_IN_BED`, `DISCHARGE_PLANNED`, `DISCHARGED`.
- Bed statuses including `Available`, `Occupied`, `Cleaning` for housekeeping/IPD integration tests.

---

## Current State (read before changing code)

| Area | Location | Notes |
|------|----------|-------|
| Seed scripts | `backend/scripts/seeders/` | Tenant, users, clinical catalogs, Uganda diagnosis catalog, etc. |
| Env guards | `backend/.cursor/`, `constants-env` | Confirm production blocks |
| Frontend | No dedicated feature — devs run backend seed CLI | |
| Tests | Some modules use demo fixtures in tests | |

### Known gaps

- Single documented “run demo seed” entry point for new developers
- Not all app-write-up demo accounts may exist in one seeder run
- OPD/IPD end-to-end demo path may require manual steps after seed
- Dental demo data not seeded (module not built)
- Clear/recreate script documentation

---

## Scope — Core Capabilities

1. **Idempotent seed command** — document primary npm/script command and flags.
2. **Demo user matrix** — table of accounts, passwords (non-prod), roles, modules.
3. **Clinical path samples** — OPD visit + IPD admission linked to same patient.
4. **Operational samples** — open maintenance request, housekeeping task, mortuary case (read-only if mutations disabled).
5. **Safety** — `NODE_ENV`/explicit flag checks; warn on production hostnames.

---

## Acceptance Criteria

- [ ] New developer can seed demo tenant and login as doctor, nurse, receptionist, cashier.
- [ ] OPD worklist has actionable demo rows per opd-flow stages.
- [ ] IPD worklist has demo admissions per ipd-flow stages.
- [ ] Seed does not run on production without explicit dangerous flag.
- [ ] Demo data labeled in DB or metadata where supported.

---

## Key File References

```
.cursor/app-write-up.mdc (Demo and Seed Data Expectations)
backend/scripts/seeders/
backend/env.template.txt

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/01-auth-module-prompt.md, prompts/02-subscriptions-module-prompt.md
```
