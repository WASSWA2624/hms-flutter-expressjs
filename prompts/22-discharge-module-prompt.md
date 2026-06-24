# Discharge Module — Implementation Prompt

## Objective

Complete the **Discharge Module** for HOSSPI HMS so doctors, nurses, pharmacists, billers, and discharge coordinators can run **multi-step inpatient discharge** end-to-end: discharge planning, pending-order checks, summary preparation, pharmacy clearance, billing finalization, nursing clearance, patient exit, bed release handoff, and encounter closure — anchored to the **IPD encounter**.

**Source of truth (read in this order):**

1. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §10–§12 discharge workflow, §12 discharge statuses, §15 role actions, §16 encounter hub
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §7 contrast: OPD `DISCHARGED` completes outpatient visit; IPD discharge is separate inpatient workflow
3. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Discharge owns summary, checks, instructions, episode closure; Billing owns financial settlement

**Central encounter rule:** discharge clearance attaches to the **IPD admission / encounter**. Discharge does not create parallel records; it orchestrates clearance across departments on the same admission.

Deliver a **calm clearance workspace**: queue of patients in `DISCHARGE_PLANNED` and clearance substates, checklist visibility per role, and handoff to Housekeeping after bed release.

---

## Mandatory Reading (before any Discharge change)

1. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — discharge mermaid flow §10, steps table, §11 `DISCHARGE_PLANNED` / clearance stages, §12 discharge statuses.
2. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §8 completion; do not confuse OPD visit closure with IPD discharge.
3. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Discharge vs Billing vs Pharmacy vs Nursing vs Mortuary (death pathway).

---

## Flow Integration Requirements

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD step / concept | Discharge module responsibility |
| ------------------ | ------------------------------- |
| Step 15: Discharge planning | Doctor marks ready; queue shows `DISCHARGE_PLANNED` |
| Step 16: Final clearance | Multi-party checklist: doctor summary, pharmacy, billing, nursing |
| Step 17: Patient exit | Confirm exit after clearances |
| Step 18: Bed release | Trigger bed `Cleaning` / housekeeping handoff after exit |
| Step 19: Encounter closure | `finalize-discharge` closes IPD encounter |
| §10 pending orders | System checks lab, radiology, procedure, medication, consult, nursing tasks |
| §12 discharge statuses | Map UI to `Planned`, `Summary Pending`, `Medication Pending`, `Billing Pending`, `Nursing Clearance Pending`, `Documents Ready`, `Patient Exited`, `Completed` |
| §11 backend stages | `DISCHARGE_PLANNED`, `DISCHARGED`; align with `plan-discharge` / `finalize-discharge` |
| §16 Encounter hub | All clearance panels scoped to `admissionId` |

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Discharge module responsibility |
| ----------- | ------------------------------- |
| `DISCHARGED` (OPD) | Outpatient visit complete — **not** handled in Discharge module |
| `ADMITTED` | Patient left OPD queue; IPD discharge workflow applies when inpatient episode ends |
| No OPD mutations | Discharge module does not change OPD stages |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Discharge implementation |
| ------------ | ------------------------ |
| Discharge row | Summary, checks, instructions, care episode closure |
| Billing boundary | Financial clearance via Billing workspace — show status, link out |
| Pharmacy boundary | Take-home medicines clearance — read open pharmacy orders |
| Nursing boundary | Nursing clearance step — coordinate with Nursing module |
| Mortuary boundary | In-hospital death uses mortuary pathway — not normal discharge |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/discharge/` | Workspace page, controller, repository |
| IPD orchestration | `GET /ipd-flows`, `plan-discharge`, `finalize-discharge` | Queue filtered by discharge-related stages |
| Clearance UI | Client-side checklist | Doctor, nursing, pharmacy, billing, bed sections |
| Auxiliary APIs | `GET /pharmacy-orders`, `GET /invoices` | Open orders and billing context for clearance |
| Localization | `app_en.arb` | Discharge workspace strings |

### Known gaps to close

- **Insurance / housekeeping clearance** — marked unavailable in UI; wire when backend supports.
- **Bed release action** — not triggered from Discharge UI after finalize; coordinate with IPD/Housekeeping.
- **Discharge summaries API** — `discharge-summary` entity exists; frontend may not use dedicated CRUD.
- **Overlap with Clinical** — legacy `POST /admissions/:id/discharge` vs IPD flow finalize — consolidate on ipd-flow.
- **Clearance substates** — backend may not expose distinct billing/pharmacy/nursing substates; document mapping.
- **Deep links** — `/discharge?id=` query params not parsed in router.
- **Tests** — no `test/features/discharge/` coverage.

---

## Scope — Core Capabilities

### 1. Discharge queue

- List IPD admissions in `DISCHARGE_PLANNED` and clearance-in-progress states.
- Summary cards filter queue (mirror IPD §14 and OPD §6 patterns).
- Show pending items count per clearance domain.

### 2. Plan discharge

- `POST /ipd-flows/:id/plan-discharge` with expected date, notes, pending-order review.
- Block or warn when critical pending orders exist (ipd-flow §10).

### 3. Multi-step clearance

- **Doctor:** discharge summary, final diagnosis, advice, follow-up.
- **Pharmacy:** take-home medicines; open order clearance.
- **Billing:** final bill, balance zero or insured; link to Billing workspace.
- **Nursing:** patient education, ward checklist.
- **Bed:** release for cleaning after patient exit.

### 4. Finalize discharge

- `POST /ipd-flows/:id/finalize-discharge` when all required clearances complete.
- Print/share discharge documents; mark `DISCHARGED` / encounter closed.

### 5. Cross-module links

- Open Billing, Pharmacy, Nursing, IPD, Housekeeping with admission context.
- Mortuary pathway for death — do not route through standard discharge finalize.

---

## Acceptance Criteria

- [ ] Queue shows IPD patients in discharge stages per ipd-flow §10–§12.
- [ ] Plan and finalize discharge work end-to-end via ipd-flow APIs.
- [ ] Clearance checklist reflects pharmacy, billing, nursing, doctor status.
- [ ] Bed release / housekeeping handoff documented or wired after exit.
- [ ] OPD `DISCHARGED` not conflated with IPD discharge in UI copy.
- [ ] No raw UUIDs; permissions enforced; tests added for primary flows.

---

## Key File References

```
.cursor/flows/ipd-flow.mdc
frontend/lib/features/discharge/
backend/src/modules/ipd-flow/
backend/src/modules/discharge-summary/

Related prompts: prompts/19-ipd-module-prompt.md, prompts/09-billing-module-prompt.md, prompts/18-pharmacy-module-prompt.md, prompts/15-nursing-module-prompt.md, prompts/27-housekeeping-module-prompt.md
```
