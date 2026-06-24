# Biomedical Module — Implementation Prompt

## Objective

Complete the **Biomedical Engineering Module** for HOSSPI HMS so biomedical technicians and managers can run **clinical equipment lifecycle** end-to-end: equipment registry, categories, maintenance plans, work orders, calibration, safety testing, downtime, incidents, recalls, spare parts, service providers, warranties, utilization, and disposal/transfer — supporting safe clinical operations in OPD, IPD, ICU, and Theater.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Biomedical vs Operations vs Theater vs IPD boundaries
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §3 bed equipment needs, §6 bed suitability, §14 bed board equipment constraints
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 no clinical actions for unrelated roles; facility issues route to Operations, **clinical device faults** to Biomedical

**Module boundary:** Biomedical owns **clinical/medical equipment** lifecycle. Operations owns non-clinical facility maintenance (HVAC, plumbing, general building). Equipment downtime may affect bed assignability and theater/ICU readiness — surface status to IPD/theater when linked to ward/bed/room.

Deliver an **audit-ready equipment workbench**: fault-to-work-order pipeline, PM schedules, calibration due dates, and downtime visibility.

---

## Relationship to OPD and IPD flows

Biomedical does not own patient encounters. Integration is **operational**:

| Flow reference | Biomedical responsibility |
| -------------- | ------------------------- |
| ipd-flow §3 bed suitability | Equipment requirements (ventilator, isolation) — bed assign fails or warns when required device down |
| ipd-flow §14.2 bed board | Show equipment-linked downtime on bed/room when API provides |
| ICU / Theater | Critical devices (monitors, ventilators) — work orders prioritized; link equipment registry to location |
| Operations handoff | Non-clinical issues converted from Operations — clinical equipment faults stay in Biomedical |
| opd-flow §5 | Biomedical staff do not perform OPD clinical actions |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/biomedical/` | Workbench, fault reports, work-order actions |
| Biomedical workspace | `backend/src/modules/biomedical-workspace/` | `GET /biomedical`, lookups, `POST /biomedical/fault-reports` |
| Equipment modules | `equipment-work-order`, `equipment-registry`, `equipment-maintenance-plan`, calibration, downtime, spare-parts, etc. | Granular legacy CRUD |
| Feature flag | `biomedical_workspace_v1` | Required for workspace |
| Operations cross-link | Operations can convert to biomedical work order | See prompts/16-operations-module-prompt.md |

### Known gaps to close

- **Workspace mutations thin** — most CRUD via legacy equipment routes; align repository with workspace API growth.
- **IPD bed equipment constraints** — not wired on bed assign UI.
- **Location linkage** — ward/room/bed/ICU/theater on equipment registry.
- **PM/calibration due queues** — summary cards for overdue PM/calibration.
- **Feature flag documentation** — enablement for dev/demo.
- **Frontend tests** — service/repo tests exist; expand UI tests.
- **Deep links** — `/biomedical?id=` query params.

---

## Scope — Core Capabilities

### 1. Equipment registry and categories

- Searchable registry with location, status, warranty, service provider.

### 2. Fault reports and work orders

- Report fault from workspace; create/start/complete work orders.
- Return to service with safety sign-off.

### 3. Maintenance plans and calibration

- Scheduled PM; calibration and safety testing due dates.
- Overdue queues and notifications.

### 4. Downtime and incidents

- Record downtime; link to beds/rooms/theater when clinical impact.
- Incident and recall tracking.

### 5. Cross-module integration

- Operations → Biomedical conversion for clinical devices.
- IPD/theater bed pickers respect equipment-down flags when backend supports.

---

## Module Boundaries (do not violate)

From `../.cursor/app-write-up.mdc`:

- Biomedical owns clinical equipment — not housekeeping cleaning, not general plumbing/HVAC (Operations).
- Do not mutate OPD/IPD patient stages.
- Do not own theater surgical documentation — only equipment used in theater.

---

## Acceptance Criteria

- [ ] Equipment registry and work-order lifecycle usable from workspace.
- [ ] Fault report → work order → return-to-service flow complete.
- [ ] PM/calibration due visibility for managers.
- [ ] Clear boundary vs Operations module.
- [ ] Optional IPD bed equipment constraint when API available.
- [ ] Feature flag and permissions enforced; tests pass.

---

## Key File References

```
frontend/lib/features/biomedical/
backend/src/modules/biomedical-workspace/
backend/src/modules/equipment-work-order/, equipment-registry/

Related prompts: prompts/16-operations-module-prompt.md, prompts/05-ipd-module-prompt.md, prompts/06-icu-module-prompt.md, prompts/07-theater-module-prompt.md
```
