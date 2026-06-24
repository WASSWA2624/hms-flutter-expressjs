# Dental Module — Implementation Prompt

## Objective

Complete the **Dental Module** for HOSSPI HMS (planned) so dental officers can manage oral health care end-to-end within **outpatient and emergency workflows**: dental triage, examinations, tooth-level charting, diagnoses, procedures (fillings, extractions, scaling, root canal), dental imaging links, treatment plans, prescriptions, and follow-up visits.

**Status:** Listed in [app-write-up.mdc](../.cursor/app-write-up.mdc) but **no dedicated `features/dental/` frontend or `dental-workspace` backend exists yet**. Use this prompt when implementing the module from scratch.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Dental row and module boundaries
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — dental care within OPD visit; disposition and follow-up
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — inpatient dental consult only if admitted; rare — default OPD encounter parent

**Central rule:** dental episodes attach to **OPD encounter** (or emergency encounter) unless patient is admitted — then document on IPD encounter without duplicating admission. Dental owns tooth chart and dental procedures — Clinical owns general consultation patterns; share order/billing patterns with [prompts/14-clinical-module-prompt.md](./14-clinical-module-prompt.md).

---

## Flow Integration Requirements (target design)

### OPD flow

| OPD concept | Dental module responsibility |
| ----------- | ---------------------------- |
| `WAITING_DOCTOR_REVIEW` / dental clinic queue | Route to dental officer; optional `DENTAL_REQUESTED` stage if backend extends OPD contract |
| `WAITING_DISPOSITION` | Complete dental episode; discharge, follow-up dental visit, or admit |
| Orders | Dental imaging → [prompts/17-radiology-module-prompt.md](./17-radiology-module-prompt.md); prescriptions → [prompts/18-pharmacy-module-prompt.md](./18-pharmacy-module-prompt.md) |
| Billing | `ClinicalRequestBillingPanel` on procedures |

### IPD flow

| IPD concept | Dental responsibility |
| ----------- | --------------------- |
| Inpatient dental consult | Orders and notes on IPD encounter — dental does not own admission |
| Discharge | Dental clearance if active plan — coordinate [prompts/22-discharge-module-prompt.md](./22-discharge-module-prompt.md) |

### App write-up

- Dental clinic service unit, chairs/rooms in facility setup ([prompts/03-tenant-facility-module-prompt.md](./03-tenant-facility-module-prompt.md)).
- Demo seed: dental officer account, sample chart entries (app-write-up Demo expectations).

---

## Recommended implementation shape

1. **Backend** — `dental-workspace` or extend `opd-flow` with dental disposition; entities: `dental-chart`, `tooth-status`, `dental-procedure`, `dental-treatment-plan`.
2. **Frontend** — `features/dental/` with tooth chart UI, procedure dialogs, worklist by OPD dental queue.
3. **Shared patterns** — mirror Physiotherapy referral handoff from OPD disposition ([prompts/23-physiotherapy-module-prompt.md](./23-physiotherapy-module-prompt.md)).

---

## Acceptance Criteria (when implemented)

- [ ] Dental officer can chart teeth and record procedures on OPD encounter.
- [ ] Imaging and pharmacy orders use existing department modules.
- [ ] OPD disposition supports dental follow-up without duplicate encounters.
- [ ] Demo seed includes sample dental data per app-write-up.
- [ ] Module entitlement and RBAC enforced.

---

## Key File References (to create)

```
.cursor/app-write-up.mdc (Dental row)
backend/scripts/seeders/ (dental demo data — partial procedure terms exist)

Related prompts: prompts/12-opd-module-prompt.md, prompts/14-clinical-module-prompt.md, prompts/08-patients-module-prompt.md
```
