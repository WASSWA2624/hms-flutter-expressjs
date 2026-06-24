# OPD Module — Implementation Prompt

## Objective

Complete the **Appointment and OPD Flow Module** for HOSSPI HMS so reception, nurses, doctors, billing, and service departments can run outpatient care end-to-end: appointment check-in, walk-in registration, triage vitals, consultation queues, diagnostics and pharmacy routing, billing gates, clinical disposition (admit, discharge, referral, follow-up), and handoff to IPD — without duplicating active OPD encounters.

**Source of truth (read in this order):**

1. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — backend stage contract, worklist contract, role rules, UI rules, OPD-to-IPD handoff, completion rules
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §2.2 OPD→IPD admission, §4 billing gates, §16 encounter hub after `ADMITTED` disposition
3. [app-write-up.mdc](../.cursor/app-write-up.mdc) — OPD flow vs OPD triage vs Clinical vs Billing boundaries

**Central encounter rule:** the **OPD encounter** is the single outpatient record while a visit is active. Do not create a second active OPD encounter for the same patient. All vitals, consultation, orders, billing, and disposition attach to that encounter.

Deliver a **professional, reception-grade workspace**: role-focused queues aligned to backend stages, summary cards that filter the worklist, hospital-language labels (not enum names), and no raw internal identifiers in the UI.

---

## Mandatory Reading (before any OPD change)

1. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §2 entry paths, §3 stage contract, §4 worklist, §5 roles, §6 UI rules, §7 IPD handoff, §8 completion.
2. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §2.2 OPD→IPD, §4 billing timing, §7 orders routed from outpatient context.
3. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — OPD flow owns arrival, queues, routing, completion; Clinical owns consultation content; Billing owns cashier workflows.

When changing OPD workflow behavior, update `opd-flow.mdc` first so flow docs and implementation stay aligned.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | OPD module responsibility |
| ----------- | ------------------------- |
| §2 Entry paths | Walk-in, appointment check-in, follow-up, emergency handoff — search patient first, reuse or create encounter |
| §3 Backend stages | UI labels, filters, badges, and actions use canonical stages: `WAITING_CONSULTATION_PAYMENT`, `WAITING_VITALS`, `WAITING_DOCTOR_ASSIGNMENT`, `WAITING_DOCTOR_REVIEW`, `LAB_REQUESTED`, `RADIOLOGY_REQUESTED`, `LAB_AND_RADIOLOGY_REQUESTED`, `PHARMACY_REQUESTED`, `WAITING_DISPOSITION`, `ADMITTED`, `DISCHARGED` |
| §4 Worklist | Patient identity, encounter context, visit type, stage, provider, billing state, wait time, next action, responsible role |
| §5 Role rules | Show actions only when stage + role both allow; backend auth is mandatory |
| §6 UI rules | Reuse `frontend/lib/shared/*`; summary cards filter worklist; hide zero-value cards; refresh affected row after modal actions |
| §7 OPD→IPD handoff | Doctor disposition `ADMIT` sets stage `ADMITTED`; navigate or link to IPD workspace with source encounter preserved |
| §8 Completion | Discharged/admitted/referred rows leave active queues unless user filters for completed |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | OPD module responsibility |
| ----------- | ------------------------- |
| §2.2 OPD→IPD admission | Pass diagnosis, reason, urgency, consultant, ward class via admission request; link `encounter_id` to new IPD admission |
| §4 Billing gates | Consultation payment gate (`pay-consultation`) before vitals/doctor when policy requires; defer only when backend allows |
| §7 Inpatient orders | After admit, IPD owns orders — OPD does not keep patient in active OPD queues |
| §16 Encounter hub | OPD encounter remains linked as source on IPD admission detail |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | OPD implementation |
| ------------ | ------------------ |
| Appointment and OPD flow row | Arrivals, queues, routing, consultation readiness, outpatient completion |
| OPD triage boundary | Pre-consultation triage may use `/triage` APIs — coordinate, do not duplicate routing logic |
| Clinical boundary | Doctor review and disposition live in OPD workspace actions; clinical notes/orders use shared clinical actions |
| Billing boundary | Payment gate and consultation billing via billing integration — not full cashier desk in OPD |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| OPD flow spec | `../.cursor/flows/opd-flow.mdc` | Canonical stages and UI contract |
| Frontend scaffold | `frontend/lib/features/opd/` | Full data/domain/presentation layers |
| Workspace UI | `opd_workspace_page.dart` | Worklist, summary cards, stage actions, appointments panel, billing, disposition |
| Controller | `opd_workspace_controller.dart` | Realtime sync, pagination, stage mutations, appointments |
| Repository | `opd_repository.dart` / `opd_repository_impl.dart` | `GET/POST /opd-flows`, summary, start/bootstrap, pay-consultation, vitals, assign-doctor, doctor-review, disposition |
| Triage | `backend/src/modules/triage/` | Parallel triage queue; OPD embeds vitals routing |
| Backend tests | `backend/src/tests/modules/opd-flow/` | Service, routes, RBAC, schema |
| Billing | `opd_billing_state.dart`, `opd_flow_actions_dialog.dart` | Consultation payment gate |
| Clinical orders | Shared `clinical_actions` | Lab/radiology/pharmacy from doctor review |
| Shell | `app_router.dart` | `/opd` route with workload badge |
| Localization | `app_en.arb` | Substantial OPD strings |

### Known gaps to close

- **IPD handoff navigation** — disposition `ADMIT` updates stage but may not deep-link to IPD workspace with patient/admission pre-selected.
- **Triage split** — vitals routing spans `/triage` and OPD APIs; unify nurse queue experience with Nursing module where appropriate.
- **Completed visit filtering** — ensure `DISCHARGED` and `ADMITTED` rows do not clutter active action queues by default.
- **Emergency handoff** — preserve emergency context on encounter; avoid duplicate OPD encounter per opd-flow §2.
- **Deep links** — parse `/opd?id=&panel=` query params in router.
- **Large page file** — `opd_workspace_page.dart` (~3.2k lines); extract widgets per conventions.
- **Frontend tests** — expand beyond backend coverage for stage transitions and disposition flows.

---

## Scope — Core Capabilities

### 1. OPD worklist and stage contract

- Align all queue scopes, summary cards, and row badges to backend OPD stages (opd-flow §3).
- Default landing: highest workload stage for current role (reception → payment/vitals; doctor → review/disposition).
- Worklist columns per §4; use display IDs only.

**Reference APIs:** `GET /opd-flows`, `GET /opd-flows/summary`, `POST /opd-flows/start`, `POST /opd-flows/bootstrap`.

### 2. Entry paths and encounter lifecycle

- Walk-in / appointment / follow-up / emergency handoff per §2.
- Reuse active encounter when one exists for patient; block duplicate creation.
- `PATCH /opd-flows/:id/context` for visit type, payer, provider updates.

### 3. Role-based stage actions

- Reception: registration, check-in, provider assignment, payment handoff.
- Nurse: `record-vitals`, assignment support when permitted.
- Doctor: `doctor-review`, orders, `disposition` (admit/discharge/referral/follow-up/physiotherapy/etc.).
- Billing: `pay-consultation` only — no clinical actions.
- Lab/Radiology/Pharmacy: service workspaces only — no OPD stage mutations from those modules.

### 4. Diagnostics and pharmacy routing

- Stages `LAB_REQUESTED`, `RADIOLOGY_REQUESTED`, `LAB_AND_RADIOLOGY_REQUESTED`, `PHARMACY_REQUESTED` reflect pending department work.
- Orders created via clinical actions; OPD stage advances when backend orchestrator detects completion.

### 5. OPD-to-IPD handoff

- On `ADMIT` disposition: show confirmation, link to IPD workspace, preserve source OPD encounter on IPD detail (ipd-flow §2.2, opd-flow §7).
- OPD stage `ADMITTED` is terminal for outpatient queue purposes.

### 6. Billing integration

- Consultation payment gate before vitals/doctor when `WAITING_CONSULTATION_PAYMENT`.
- Pay-now vs bill-later for orders via `ClinicalRequestBillingPanel`; billing desk reflects status in Billing module.

---

## Module Boundaries (do not violate)

From `../.cursor/app-write-up.mdc`:

- **OPD flow** owns queues and routing — not inpatient bed management, not ICU stays, not discharge clearance.
- **Clinical** owns consultation documentation depth — OPD orchestrates stages.
- **IPD** owns admission after `ADMITTED` disposition.
- **Billing** owns invoices, payments, claims — OPD triggers gates only.

---

## Architecture and Conventions

Follow `frontend/.cursor/` rules and `backend/.cursor/` API standards.

| Rule | Requirement |
|------|-------------|
| Layering | UI → repository → API; no API calls from widgets |
| State | Riverpod `AsyncNotifier`; `Result<T>` / `AppFailure` |
| Localization | All strings in `app_en.arb` |
| Permissions | RBAC + module entitlements; mirror backend in UI gates |
| Shared UI | `AppWorkspace`, `AppListTable`, `opd_flow_actions_dialog`, `frontend/lib/shared/opd_actions/` |

---

## Acceptance Criteria

- [ ] Worklist stages match backend contract and opd-flow §3.
- [ ] All entry paths create or reuse a single active OPD encounter.
- [ ] Role-visible actions match opd-flow §5; backend rejects invalid actions.
- [ ] Summary cards filter the worklist per §6.
- [ ] `ADMIT` disposition hands off to IPD with source context (opd-flow §7, ipd-flow §2.2).
- [ ] `DISCHARGED` and terminal states leave active queues by default.
- [ ] Consultation billing gate works; orders route to lab/radiology/pharmacy workspaces.
- [ ] No raw UUIDs in UI; localized strings; `flutter analyze` and tests pass.

---

## Key File References

```
.cursor/flows/opd-flow.mdc
.cursor/flows/ipd-flow.mdc
.cursor/app-write-up.mdc

frontend/lib/features/opd/
backend/src/modules/opd-flow/
backend/src/modules/triage/

Related prompts: prompts/19-ipd-module-prompt.md, prompts/14-clinical-module-prompt.md, prompts/09-billing-module-prompt.md, prompts/16-lab-module-prompt.md, prompts/17-radiology-module-prompt.md
```
