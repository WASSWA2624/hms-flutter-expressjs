# Theater Module — Implementation Prompt

## Objective

Complete the **Theater (Operating Theatre) Module** for HOSSPI HMS so surgeons, anesthetists, nurses, and theater coordinators can run surgical episodes end-to-end: schedule cases, pre-theater checks, anesthesia records, intra-operative tracking, post-operative notes, and **handover back to ward, ICU, or outpatient care** — linked to the **IPD encounter** (or emergency/OPD source context).

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Theater module boundaries vs IPD, ICU, Nursing, Clinical, Billing, Emergency
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §7 surgery route, §9 OT/procedure transfer, §11 `In Procedure / OT`, §15 OT role actions, §16 encounter hub
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — elective cases may originate from OPD disposition; emergency handoff from Emergency module

**Central encounter rule:** theater cases attach to **IPD admission** (inpatient surgery) or linked encounter from emergency/OPD pathways. Theater does not create parallel admission records — it orchestrates the surgical episode on the existing encounter.

Deliver a **professional theater workspace**: case board by stage, resource assignment (room, team), checklist-driven safety, and post-op handover summaries visible on ICU/Nursing detail.

---

## Mandatory Reading (before any Theater change)

1. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Theater owns bookings, flow, pre-op checks, anesthesia, procedure status, post-op notes, handover.
2. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — surgery order routing, temporary OT transfer, post-op return to ward/ICU.
3. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — planned procedures from outpatient planning paths.

---

## Flow Integration Requirements

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Theater module responsibility |
| ----------- | ----------------------------- |
| §7 Surgery route | OT scheduling → pre-op checklist → operation → post-op care |
| §7 Order output | Operative note, anesthesia note, post-op orders, charges |
| §9 OT/procedure transfer | Temporary movement to OT; return to ward/ICU with handover |
| §11 `In Procedure / OT` | Case board shows active intra-op cases |
| §4 Billing gates | Pre-auth / deposit before high-cost procedure when policy requires |
| §16 Encounter hub | Case, anesthesia, checklists, post-op notes on admission encounter |

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Theater module responsibility |
| ----------- | ----------------------------- |
| Planned elective surgery | May schedule from OPD consultation — preserve OPD encounter link on case |
| `ADMITTED` for surgery | Patient admitted for procedure — IPD owns admission; theater owns case lifecycle |
| §5 Role rules | Theater team actions in theater workspace only |

### Emergency handoff

| Source | Theater responsibility |
| ------ | -------------------- |
| Emergency `THEATER` disposition | Case created with emergency context; link `emergency_case_id` when available |
| Post-op | Handover to ICU (critical) or ward per clinical decision — show summary on ICU/Nursing detail |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Theater implementation |
| ------------ | ---------------------- |
| Theater row | Bookings, flow, anesthesia, post-op, handover |
| IPD boundary | Admission and bed — theater owns surgical episode overlay |
| ICU boundary | Post-op ICU handoff summary on ICU detail when reference exists |
| Billing boundary | Procedure charges via billing integration — not cashier in theater |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/theater/` | Workspace page, controller, repository |
| Theatre flow API | `backend/src/modules/theatre-flow/` | `GET /theatre-flows`, `POST /theatre-flows/start`, stage updates, anesthesia, post-op, checklists, resource assign/release |
| Repository | `theater_repository_impl.dart` | listCases, getCase, scheduleCase, stage mutations |
| Emergency upstream | `emergency-case.service.js` | Theater disposition path |
| ICU integration | ICU detail may show theatre reference | Post-op handoff context |

### Known gaps to close

- **Prompt/documentation** — was empty; align UI with full theatre-flow stage contract.
- **IPD status sync** — `In Procedure / OT` on IPD board when case active.
- **Pre-op billing gate** — high-cost procedure authorization (ipd-flow §4).
- **Post-op orders** — route medication/lab orders back to IPD encounter after case.
- **Deep links** — `/theater?id=` query params in router.
- **Localization audit** — ensure all strings in `app_en.arb`.
- **Frontend tests** — add controller and workflow tests.
- **Large page file** — extract widgets if monolithic.

---

## Scope — Core Capabilities

### 1. Theater case board

- Queue scopes: scheduled, pre-op, in progress, post-op, completed, cancelled.
- Columns: patient, case ID, procedure, room, surgeon, anesthetist, scheduled time, stage, next action.

### 2. Case lifecycle

- `POST /theatre-flows/start` — schedule with admission/encounter link.
- Stage transitions via `update-stage`; resource assign/release for rooms and team.
- Pre-op checklist toggle items; anesthesia record and observations.
- Post-op note upsert; finalize/reopen records per policy.

### 3. IPD and transfer integration

- Request OT transfer from IPD when patient in ward; complete handover back to ward/ICU.
- IPD detail link **Open in Theater** when active case exists.

### 4. Billing and orders

- Procedure charges post per billing rules; `ClinicalRequestBillingPanel` on related orders.
- Post-op medication/lab orders on IPD encounter via clinical actions.

### 5. Cross-module handover

- Post-op summary visible on Nursing and ICU workspaces.
- Emergency source context on case detail when applicable.

---

## Module Boundaries (do not violate)

- Do not own IPD admission creation (except via upstream handoff).
- Do not own ICU stay lifecycle — hand off to ICU module after post-op.
- Do not duplicate anesthesia documentation in Clinical module if theater owns canonical record.

---

## Acceptance Criteria

- [ ] Case board aligns with theatre-flow backend stages.
- [ ] Cases link to IPD admission / encounter on all mutations.
- [ ] Pre-op, intra-op, and post-op workflows completable in UI.
- [ ] Post-op handover visible on ICU/Nursing when configured.
- [ ] OPD/elective and emergency entry paths preserve source context.
- [ ] No raw UUIDs; permissions enforced; tests pass.

---

## Key File References

```
frontend/lib/features/theater/
backend/src/modules/theatre-flow/
backend/src/modules/emergency-case/

Related prompts: prompts/19-ipd-module-prompt.md, prompts/20-icu-module-prompt.md, prompts/13-emergency-module-prompt.md, prompts/09-billing-module-prompt.md
```
