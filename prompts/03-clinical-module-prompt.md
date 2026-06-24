# Clinical Module — Implementation Prompt

## Objective

Complete the **Clinical Module** for HOSSPI HMS so doctors and authorized clinicians can run consultations end-to-end across **outpatient and inpatient** contexts: review encounters, document notes and diagnoses, place orders (lab, radiology, pharmacy, procedures), manage care plans and follow-ups, and coordinate handoffs — while respecting OPD and IPD flow orchestration.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Clinical module boundaries vs OPD, Nursing, IPD, Lab, Pharmacy, Billing
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §3 stages for outpatient work, §5 doctor responsibilities, §6 UI rules, §7 admit handoff
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §6–§8 doctor care, §7 orders, §11 inpatient stages, §16 IPD encounter as hub

**Central encounter rule:** clinical artifacts attach to the **active encounter** — OPD encounter for outpatient, IPD admission encounter for inpatient. Clinical does not create parallel admission or OPD flow records.

Deliver a **professional doctor workspace**: unified worklist for OPD + IPD patients, order placement with billing choice, realtime result notifications, and clear module boundaries.

---

## Mandatory Reading (before any Clinical change)

1. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Clinical owns consultations, notes, diagnoses, procedures, care plans, orders.
2. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — doctor stages and disposition; OPD owns queue movement.
3. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — inpatient orders, ward rounds, care loop, discharge decisions.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Clinical module responsibility |
| ----------- | ------------------------------ |
| `WAITING_DOCTOR_REVIEW` | Doctor opens patient from clinical worklist or OPD workspace; consultation actions advance OPD via OPD APIs |
| `LAB_*` / `PHARMACY_REQUESTED` | Clinical places orders; OPD stage updated by opd-flow orchestrator when pending work exists |
| `WAITING_DISPOSITION` | Disposition (admit/discharge/referral) triggered from OPD actions — clinical documents support the decision |
| §5 Doctor role | Consultation, orders, disposition — not reception or cashier actions |
| §7 OPD→IPD | Admit disposition creates IPD admission; clinical shows IPD context after handoff |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Clinical module responsibility |
| ----------- | ------------------------------ |
| §6 Doctor inpatient care | Review admission, assessment, care plan, progress notes, ward round notes |
| §7 Orders | Medication, lab, radiology, procedure, diet, consult, nursing instructions — via shared clinical actions on IPD encounter |
| §8 Care loop | Orders → departments → results → review; clinical worklist surfaces pending results |
| §10–§12 Discharge | Doctor marks discharge planned; Discharge module owns clearance workflow |
| §16 Encounter hub | All clinical notes/orders on `encounter_id` / admission ID — migrate from legacy `/admissions` where needed |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Clinical implementation |
| ------------ | ----------------------- |
| Clinical module row | Consultations, notes, diagnoses, procedures, care plans, orders, follow-up |
| OPD boundary | OPD owns queue stages; clinical owns consultation content |
| IPD boundary | IPD owns admission lifecycle; clinical owns doctor documentation and orders on admission |
| Nursing boundary | Nursing executes MAR and tasks — clinical places orders |
| Billing boundary | `ClinicalRequestBillingPanel` at order time; Billing owns cashier desk |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/clinical/` | Workspace page, controller, repository |
| Worklist | Merges OPD flows + triage + inpatient admissions | `OpdRepository`, `/admissions`, `/encounters` |
| Shared clinical actions | `frontend/lib/shared/clinical_actions/` | Lab, radiology, prescription dialogs + billing panel |
| Backend modules | `clinical-note`, `diagnosis`, `procedure`, `care-plan`, `lab-order`, `radiology-order`, `pharmacy-order`, `encounter`, `admission`, `referral`, `follow-up` | Granular CRUD APIs |
| Realtime | Lab result ready notices in clinical workspace | Snackbar on `LAB_RESULT_READY` |
| Localization | `app_en.arb` | Clinical workspace strings |

### Known gaps to close

- **IPD flow integration** — inpatient worklist uses legacy `/admissions` not `GET /ipd-flows`; discharge uses `POST /admissions/:id/discharge` vs IPD `plan-discharge`/`finalize-discharge`.
- **Start IPD admission** — should align with `POST /ipd-flows/start` from IPD module, not duplicate admission paths.
- **Unified encounter context** — outpatient vs inpatient tabs/filters should show source module and stage clearly.
- **Order status visibility** — pending lab/radiology/pharmacy on detail panel from department APIs.
- **No clinical-workspace aggregator API** — client composes multiple endpoints; consider backend workspace when scaling.
- **Large page file** — `clinical_workspace_page.dart` (~3.4k lines); extract widgets.
- **Tests** — limited frontend coverage for order flows and encounter switching.

---

## Scope — Core Capabilities

### 1. Unified clinical worklist

- Filter by context: OPD, IPD, follow-up, pending results.
- Columns: patient, encounter/admission ref, stage, location, pending orders, next action.
- Realtime refresh on lab/radiology/pharmacy events.

### 2. Consultation documentation

- Clinical notes, diagnoses (ICD/terms), procedures, care plans, follow-ups.
- Link to patient registry for allergies and demographics.

### 3. Clinical orders (cross-flow)

- Lab, radiology, pharmacy orders with `ClinicalRequestBillingPanel` (pay now / bill later).
- Orders route to department queues per ipd-flow §7 / opd-flow §3 stages.
- IPD and OPD encounters both supported via `encounter_id`.

### 4. Inpatient alignment

- Prefer `ipd-flows` APIs for inpatient list/detail when implementing IPD integration.
- Ward round notes via `add-ward-round` on IPD flow.
- Coordinate with Nursing (execution) and Discharge (clearance) — clinical does not finalize discharge alone.

### 5. OPD alignment

- Doctor review and disposition remain coordinated with OPD workspace — avoid conflicting stage mutations.
- Deep-link from OPD row to clinical detail with encounter pre-selected.

---

## Module Boundaries (do not violate)

- Do not own OPD queue stages, IPD bed board, nursing MAR, lab processing, pharmacy dispensing, or billing cashier workflows.
- Do not duplicate charges — billing follows order billing choice and auto-posting rules.

---

## Acceptance Criteria

- [ ] Doctors can document and order from OPD and IPD contexts on correct encounter.
- [ ] Orders appear in Lab/Pharmacy/Radiology workspaces with billing choice respected.
- [ ] OPD admit disposition links to IPD; clinical shows inpatient context after handoff.
- [ ] IPD orders use ipd-flow encounter hub when migration complete.
- [ ] Module boundaries match app-write-up; no raw UUIDs in UI.

---

## Key File References

```
frontend/lib/features/clinical/
frontend/lib/shared/clinical_actions/
backend/src/modules/clinical-note/, lab-order/, pharmacy-order/, radiology-order/
backend/src/modules/opd-flow/, ipd-flow/

Related prompts: prompts/01-opd-module-prompt.md, prompts/05-ipd-module-prompt.md, prompts/09-lab-module-prompt.md, prompts/10-pharmacy-module-prompt.md, prompts/19-radiology-module-prompt.md
```
