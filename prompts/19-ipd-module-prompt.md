# IPD Module — Implementation Prompt

## Objective

Complete the **Inpatient (IPD) Module** for HOSSPI HMS so admission desk, bed managers, ward nurses, doctors, and discharge coordinators can run the full inpatient lifecycle end-to-end: admission intake, bed allocation, ward handover, clinical care and orders, transfers, configurable billing gates, multi-step discharge clearance, bed release, and encounter closure.

**Source of truth:** implement the workflow defined in [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc). UI labels, queue scopes, stage chips, summary cards, role visibility, and available actions must stay aligned with that document and with the **backend IPD stage contract** (`ADMITTED_PENDING_BED`, `ADMITTED_IN_BED`, `TRANSFER_REQUESTED`, `TRANSFER_IN_PROGRESS`, `DISCHARGE_PLANNED`, `DISCHARGED`, `CANCELLED`).

**OPD and emergency upstream:** align admission intake with [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) §7 (`ADMITTED` handoff) and emergency paths in ipd-flow §2.1. Product scope: [app-write-up.mdc](../.cursor/app-write-up.mdc).

**Central encounter rule:** the IPD encounter/admission is the single anchor record. Admission requests, source OPD/emergency encounters, bed history, nursing assessment, vitals, doctor notes, orders, results, billing, insurance, and discharge artifacts must attach to it — never duplicate parallel admission records.

Deliver a **professional, calm, ward-grade workspace** that is easy to scan under pressure: clear hierarchy, role-focused queues, predictable primary actions, and no raw internal identifiers in the UI.

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Use [opd-flow.mdc](../.cursor/flows/opd-flow.mdc) and [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) for journey touchpoints; read the module-specific flow file when one exists (lab, nursing, pharmacy, radiology, discharge, emergency, icu, theater). |
| Encounters | One active OPD encounter per outpatient visit; IPD admission as inpatient hub; overlays (ICU, Theater) and executing departments attach — never parallel admission records. |
| UI/UX | Modern, clean, minimal on-screen text; hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`, `platform_guidelines.mdc`. Reuse `frontend/lib/shared/*` before creating new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Full theme support (light/dark/system). All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/opd`, `/ipd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---

## Mandatory Reading (before any IPD change)

1. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §1–§19: admission paths, bed board, billing gates, nursing/doctor care, orders, transfers, discharge, backend stage contract, encounter hub (§16).
2. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §3 `ADMITTED`, §7 OPD-to-IPD handoff, §6 UI rules.
3. Re-read downstream flows attached to IPD: [nursing-flow.mdc](../.cursor/flows/nursing-flow.mdc), [discharge-flow.mdc](../.cursor/flows/discharge-flow.mdc), [icu-flow.mdc](../.cursor/flows/icu-flow.mdc), [theater-flow.mdc](../.cursor/flows/theater-flow.mdc), [lab-flow.mdc](../.cursor/flows/lab-flow.mdc), [radiology-flow.mdc](../.cursor/flows/radiology-flow.mdc), [pharmacy-flow.mdc](../.cursor/flows/pharmacy-flow.mdc), [emergency-flow.mdc](../.cursor/flows/emergency-flow.mdc).
4. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Inpatient vs Nursing, ICU, Theater, Discharge, Billing boundaries.

When changing IPD workflow behavior, update `ipd-flow.mdc` first so flow docs and implementation stay aligned.

---

## Flow Integration Requirements

| Flow | IPD module role |
| ---- | --------------- |
| [opd-flow §7](../.cursor/flows/opd-flow.mdc) | Receive `ADMITTED` handoff; link source OPD encounter; do not keep patient in active OPD queues |
| [emergency-flow §2.1](../.cursor/flows/emergency-flow.mdc) | Emergency admission with optional `Billing Deferred` |
| [nursing-flow](../.cursor/flows/nursing-flow.mdc) | Ward admission checklist and care loop execution on same admission |
| [discharge-flow](../.cursor/flows/discharge-flow.mdc) | Multi-step clearance; `plan-discharge` / `finalize-discharge` orchestration |
| [icu-flow](../.cursor/flows/icu-flow.mdc) / [theater-flow](../.cursor/flows/theater-flow.mdc) | Overlays on same admission — bridge actions **Open in ICU/Theater** |
| Executing departments | Auto-route orders per ipd-flow §7; results feed care loop §8 |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Flow specification | `../.cursor/flows/ipd-flow.mdc` | Full 19-step workflow, admission paths, bed/billing/nursing/doctor/order/discharge design |
| Frontend scaffold | `frontend/lib/features/ipd/` | `data/`, `domain/`, `presentation/` layers exist |
| Workspace UI | `ipd_workspace_page.dart` | Patient board, scope/ward filters, summary cards, admission detail dialog, bed/transfer/discharge/clinical action panels |
| Controller | `ipd_workspace_controller.dart` | Realtime + periodic sync, pagination, scope/search/ward filters, admission mutations |
| Repository | `ipd_repository.dart` / `ipd_repository_impl.dart` | List/detail, wards/beds reference data, start admission, bed assign/release, reject, transfer, ward round, nursing note, medication administration, plan/finalize discharge |
| Backend IPD flow API | `backend/src/modules/ipd-flow/` | `/api/v1/ipd-flows` list/detail/start, assign-bed, release-bed, reject-admission, request/update-transfer, add-ward-round, add-nursing-note, add-medication-administration, plan-discharge, finalize-discharge, ICU stay/observation/critical-alert endpoints |
| Backend tests | `backend/src/tests/modules/ipd-flow/` | Service, routes, RBAC, schema coverage |
| ICU overlay (read) | Detail DTO + `IpdIcuOverlay` | `include_icu=true` on list/detail; critical-alert badges in UI |
| ICU workspace (separate) | `frontend/lib/features/icu/` | Dedicated ICU board with observations, vitals, alerts, transfer/discharge actions |
| Nursing workspace | `frontend/lib/features/nursing/` | Ward nursing queue, admission checklist, handover — uses same `ipd-flows` APIs |
| OPD / Emergency upstream | `opd-flow.service.js`, `emergency-case.service.js` | Can create IPD admissions from OPD disposition and emergency stabilization paths |
| Clinical shared UI | `clinical_admission_action_dialog.dart`, `clinical_actions.dart` | Bed assignment catalog picker reused in IPD |
| Permissions / module gate | `inpatient-bed-management` module entitlement | `clinicalRead`/`clinicalWrite` + `operationsWrite`; roles: doctor, nurse, operations, icuManager |
| Realtime | `RealtimeEventGroups.ipd` | Controller subscribes to IPD domain events |
| Localization | `app_en.arb` | IPD strings largely defined (board, filters, actions, medication fields) |
| Shell integration | `app_router.dart` | `/ipd` route with nav badge from `IpdWorkspaceState.workloadCount` |

### Known gaps to close

- **Bed board missing** — flow §14 requires both an active patient board and a live bed board; UI only has the patient/admission board. Beds are fetched only as `AVAILABLE` for assign-bed dialogs.
- **Start admission not wired in UI** — `IpdRepository.startAdmission` and `POST /ipd-flows/start` exist; controller and workspace have no create-admission action for admission desk.
- **Admission entry paths** — flow §2 (emergency, OPD→IPD, planned, referral) is partially upstream-only; IPD workspace does not surface source encounter, admission request reason, urgency, consultant, or payer context.
- **Billing / insurance gate** — flow §4 (deposit, deferred billing, pre-auth, discharge clearance) is not implemented in IPD backend or frontend; no `Billing Deferred`, deposit, or clearance panels.
- **Discharge is two-step only** — `planDischarge` + `finalizeDischarge` exist; flow §10 requires pending-order checks, pharmacy clearance, billing finalization, nursing clearance, documents, patient exit, then bed release — not modeled in UI.
- **Inpatient clinical orders** — no lab, radiology, prescription, procedure, diet, consult, or nursing-task order actions from IPD detail (unlike OPD/nursing clinical-action patterns). Only medication **administration** recording exists.
- **Nursing admission checklist** — flow §5 ward handover checklist lives in Nursing workspace; IPD detail does not expose structured nursing admission (identity confirm, baseline vitals, allergies, belongings, care plan).
- **ICU mutations not in IPD repo** — backend exposes `start-icu-stay`, `end-icu-stay`, `add-icu-observation`, `add/resolve-critical-alert`; IPD repository/controller do not call them (ICU module is separate).
- **Bed lifecycle gaps** — backend bed statuses are `AVAILABLE`, `OCCUPIED`, `RESERVED`, `OUT_OF_SERVICE`; flow recommends `Cleaning`, `Maintenance`, `Blocked` and housekeeping release workflow.
- **Deep links** — backend notifications use `/ipd?id=…&panel=…`; router does not parse query params to pre-select admission or open the correct detail panel.
- **Awaiting clearance queue** — `IpdQueueScope.awaitingClearance` maps to `DISCHARGE_PLANNED` stage only; no distinct clearance substates (billing, pharmacy, nursing) from flow §12.
- **Critical alerts summary** — `criticalAlertCount` exists on state but no summary card (unlike transfer/discharge cards).
- **Frontend tests** — no `test/features/ipd/` coverage (backend has tests).
- **Large page file** — `ipd_workspace_page.dart` (~2.2k lines) mixes board, detail, and many dialogs; needs extraction per project conventions.
- **Feature flag** — `FEATURE_IPD_WORKBENCH_V1` in `backend/env.template.txt`; confirm entitlement/flag wiring if workbench gating is required.

---

## Scope — Core Capabilities

Implement or finish the following, in priority order. Each item maps to sections in `../.cursor/flows/ipd-flow.mdc`.

### 1. Patient board and role-focused queues

**Goal:** Staff can triage admissions by stage and ward using the backend stage contract.

**Actions:**

- Keep primary layout: **board → admission detail → action panel** (`AppWorkspace`, `AppListTable`, `AppWorkspaceDetailPanel`, `AppActionList`).
- Preserve and align queue scopes with backend stages:
  - **Waiting bed** → `ADMITTED_PENDING_BED`
  - **In beds** → `ADMITTED_IN_BED`
  - **Transfers** → `TRANSFER_REQUESTED`, `TRANSFER_IN_PROGRESS`
  - **Discharge planned** → `DISCHARGE_PLANNED`
  - **Awaiting clearance** → discharge substates when API supports them; until then, document mapping
  - **Discharged** → `DISCHARGED`
  - **All** → full active/all per `queue_scope`
- Default landing: **Waiting bed** (`IpdQueueScope.admissionQueue`) — highest admission-desk workload.
- Summary cards must link to scopes; add **Critical alerts** card when `criticalAlertCount > 0`.
- Table columns per flow §14.1: patient, admission no., status/stage, ward/bed, consultant (when API provides), admitted time, length of stay, payer, alerts.
- Use display IDs (`displayId`, patient display name) — never surface raw UUIDs.
- Preserve realtime sync via `RealtimeEventGroups.ipd`; refresh selected admission after mutations.

**Reference APIs:** `GET /ipd-flows`, `GET /ipd-flows/:id?include_icu=true`.

### 2. Bed board and bed management

**Goal:** Bed managers can see ward bed occupancy and perform allocate, reserve, transfer, release, and cleaning workflows.

**Actions:**

- Add a **Bed board** area (tab, toggle, or secondary route section) per flow §14.2 — do not bury bed status only inside assign-bed dialogs.
- List beds with ward, room, bed label, class, status, current patient (if occupied/reserved), and next action.
- Extend repository to fetch beds by status (`AVAILABLE`, `OCCUPIED`, `RESERVED`, `OUT_OF_SERVICE`) and ward; map to flow-recommended statuses where backend adds them.
- Wire actions: **reserve**, **assign**, **transfer complete** (with `to_bed_id`), **release for cleaning**, **mark available** — aligned with `assign-bed`, `release-bed`, `update-transfer`, and bed CRUD APIs.
- Enforce bed suitability rules from flow §3 (gender, isolation, equipment, payer) when backend exposes constraints; show blocking reasons in UI when assign fails.
- After discharge finalize + bed release, reflect bed returning to available/cleaning state on the board.

**Reference APIs:** `GET /beds`, `POST /ipd-flows/:id/assign-bed`, `release-bed`, `update-transfer`; bed module CRUD as needed.

### 3. Admission intake and entry paths

**Goal:** Authorized staff can create and progress admissions from all entry paths defined in flow §2.

**Actions:**

- Add **Start admission** action (admission desk / operations) wired to `IpdRepository.startAdmission` → `POST /ipd-flows/start` with `patient_id`, optional `encounter_id`, `facility_id`, `ward_id`, `room_id`, `bed_id`.
- When opened from OPD/Emergency/Patients with context, pre-fill patient and source encounter; show read-only source summary (OPD note, emergency case, referral note).
- Support flow §2.1 rules: emergency may defer registration and billing — expose `Billing Deferred` when backend supports it.
- Show admission request metadata when API provides: reason, provisional diagnosis, urgency, consultant, recommended ward/class, payer.
- **Reject admission** — keep existing action with reason capture.
- Link to patient registry for incomplete registration (`Pending Registration` from flow §11).

### 4. Billing, deposit, and insurance gates

**Goal:** IPD admission and services respect configurable payment timing without blocking urgent care.

**Actions:**

- Integrate with billing module per flow §4 — do not duplicate charge capture in IPD.
- On admission detail, show billing state: deposit required/paid, insurance pre-auth status, `Billing Deferred` flag, running account balance when API provides encounter billing summary.
- Gate high-cost actions (optional procedures, elective admission) on clearance when policy requires; emergency path allows proceed-first-bill-later.
- During stay: link to the billing workspace for interim bills and deposits (`clinical_request_billing_panel` patterns where orders originate from IPD; see [prompts/09-billing-module-prompt.md](./09-billing-module-prompt.md)).
- Link to patient registry for demographics ([prompts/08-patients-module-prompt.md](./08-patients-module-prompt.md)).
- At discharge: block **Ready for exit** until billing clearance per flow §10 step 6; coordinate with billing encounter closeout.
- Auto-posted charges from orders must not be manually re-entered in IPD UI.

**Reference:** `frontend/lib/features/billing/`, `shared/clinical_actions/clinical_request_billing_panel.dart`, `backend/src/lib/billing/clinical-request-billing.js`.

### 5. Ward handover and nursing admission

**Goal:** When a patient reaches the ward, nursing can complete the admission checklist from flow §5.

**Actions:**

- Add structured **Nursing admission** section or handoff to Nursing workspace with shared admission context.
- Checklist items: receive handover, confirm identity, baseline vitals, allergies/risks, belongings, care plan start, notify doctor.
- Reuse Nursing workspace patterns (`_admissionChecklistItems`, handover APIs) where possible — avoid duplicating nursing documentation logic in IPD.
- IPD detail should show latest nursing notes, vitals summary, and handover status from admission detail payload.
- Ward nurse actions: record vitals (via nursing APIs or shared vitals form), nursing notes (existing), medication administration (existing).

### 6. Doctor inpatient care and orders

**Goal:** Doctors can review context, assess, order services, round, and update the care plan per flow §6–§8.

**Actions:**

- Patient context header: source history, allergies, vitals, nursing notes, pending results, current bed location.
- **Initial assessment** and **ward round** — extend ward round beyond free text when API supports structured assessment fields.
- Add inpatient **clinical order** actions using shared clinical-action dialogs, scoped to the IPD encounter:
  - Lab (`clinical_lab_order_action_dialog.dart`)
  - Radiology (`clinical_radiology_order_action_dialog.dart`)
  - Medication/prescription (`clinical_prescription_action_dialog.dart`)
  - Procedure, diet, consult, nursing instructions — per catalog/API availability
- Each order routes to the correct department queue (flow §7) with statuses (`Ordered`, `Waiting Payment`, `In Progress`, `Completed`, etc.) shown on admission timeline when API provides.
- Support **pay now vs bill later** on order creation via `ClinicalRequestBillingPanel`.
- Daily care loop: doctor orders → departments execute → results on timeline → doctor review; UI should surface pending results/alerts on detail.

### 7. Transfers and escalation

**Goal:** Internal and external transfers without closing the IPD encounter (flow §9).

**Actions:**

- Keep **Request transfer** and **Manage transfer** with actions `APPROVE`, `START`, `COMPLETE`, `CANCEL` and required `to_bed_id` on `COMPLETE`.
- Record and display: reason, from/to location, requested by, approved by, transfer time, handover note when API provides.
- Support transfer types in UI labels: bed, ward, ICU, isolation, OT/procedure, external — map from API transfer metadata.
- ICU transfer: coordinate with ICU workspace (`start-icu-stay` / `end-icu-stay`) — link from IPD detail or deep-link to ICU board.
- Show billing impact note when API flags chargeable transfer.

### 8. Discharge planning and multi-step clearance

**Goal:** Discharge is a workflow, not a single button (flow §10).

**Actions:**

- Replace simplistic plan/finalize-only UX with staged discharge aligned to flow §10 mermaid:
  1. Doctor marks **Discharge planned**
  2. System lists pending lab, radiology, procedure, medication, consult, nursing tasks
  3. Doctor confirms defer vs must-complete items
  4. Prepare discharge summary, prescription, follow-up
  5. Pharmacy clearance / take-home medicines
  6. Billing and insurance finalization
  7. Nursing clearance and patient education
  8. Print/share documents; **Patient exited**
  9. **Release bed** for cleaning
  10. **Close encounter** (`DISCHARGED` / `Closed`)
- Use discharge statuses from flow §12 (`Planned`, `Summary Pending`, `Medication Pending`, `Billing Pending`, `Nursing Clearance Pending`, `Documents Ready`, `Patient Exited`, `Completed`) when backend exposes them; extend backend if needed.
- **Finalize discharge** only when clearances pass or authorized override with reason.
- After exit: trigger bed release (`release-bed`) and show housekeeping next action on bed board.

### 9. Cross-module integration

**Goal:** IPD connects cleanly to OPD, Emergency, Nursing, ICU, Pharmacy, Lab, Radiology, and Billing.

**Actions:**

- **OPD → IPD:** from OPD disposition/admit action, land in IPD with admission pre-created; show linked OPD encounter on detail.
- **Emergency → IPD:** show emergency case source; support deferred registration/billing flags.
- **Deep links:** handle `/ipd?id={admissionDisplayId}&panel={beds|nursing|medication|discharge|transfer|rounds}` — select admission and scroll/focus panel (backend `resolve-legacy` and notification `target_path` patterns).
- **Nursing / ICU:** clear navigation between modules for same admission without losing context.
- **Notifications:** critical results, pending discharge, transfer requests surface on board badges and admission alerts.

### 10. Admin configuration (read-mostly in IPD UI)

**Goal:** Wards, beds, packages, and policies are configurable per flow §13 Admin role.

**Actions:**

- Ward/bed pickers use live catalog from `/wards` and `/beds`.
- If admin bed/ward management UI lives elsewhere, link from IPD bed board (“Manage beds”) rather than reimplementing CRUD in IPD.
- Respect module entitlement `inpatient-bed-management` on all IPD routes and actions.

---

## UI / UX Requirements

Follow `frontend/.cursor/ui-patterns.mdc`, `design-system.mdc`, `components.mdc`, and `layouts.mdc`. Mirror proven workspace patterns from **Lab**, **Radiology**, **Pharmacy**, and **Nursing** (`AppWorkspace`, `AppListTable`, `AppWorkspaceDetailPanel`, `AppActionPanel`, `AppWorkspacePatientContextHeader`).

### Organization

- **Two primary boards**, clearly separated (flow §14):
  1. **Patient board** — active IPD admissions and queues (default).
  2. **Bed board** — live bed occupancy and bed operations.
- **Single primary task per region:** list/board (left/main), detail (dialog or split panel), actions (grouped panel).
- **Progressive disclosure:** summary metric cards for workload; ward/scope filters in advanced filter; complex forms in dialogs only.
- **Role-appropriate actions:** admission desk (create, assign bed, payer), bed manager (board, reserve, transfer), nurse (handover, vitals, notes, MAR), doctor (assess, orders, discharge plan), billing (clearance links) — per flow §13.
- Default landing: **Waiting bed** queue.

### Simplicity

- **Reduce visual noise:** one stage chip + one next-action column; avoid duplicate status badges.
- **Limit table columns** to ward-round essentials; optional columns via column visibility.
- **Action panel hierarchy:** primary next step first (assign bed when pending → clinical actions when in bed → discharge when planned), destructive actions last (reject admission).
- **Discharge UI:** stepper or checklist for clearance states — not one undifferentiated “finalize” button.
- **Forms:** one column on narrow viewports; inline validation; datetime fields for administration/transfer timestamps.
- **Loading/saving:** `AppWorkspace` status tone; no full-page reload for minor updates.

### Professional healthcare feel

- Accurate terminology: admission, ward round, transfer, discharge summary, medication administration, clearance — not generic “submit” or “item”.
- Calm visual hierarchy: neutral backgrounds; status color on chips, alerts, and critical balances only.
- Audit-friendly: show who/when on notes, transfers, and discharge steps when API provides actor metadata.
- Accessibility: semantic labels on search, tables, queue chips, and action buttons; keyboard-navigable dialogs.
- No raw UUIDs, internal enum codes, or debug field names in production UI.

---

## Architecture and Conventions

Follow `frontend/docs/workflows/feature-workflow.md` and `../.cursor/` rules. **Re-read `../.cursor/flows/ipd-flow.mdc` before any IPD flow change.**

| Rule | Requirement |
|------|-------------|
| Layering | UI/controllers → repository interface → repository impl → API client. No API calls from widgets. |
| State | Riverpod `AsyncNotifier` controllers; `Result<T>` / `AppFailure` for errors. |
| DTOs | `data/dtos/` with explicit mappers to `domain/entities/`. |
| Localization | All user strings in `app_en.arb`; run codegen. |
| Permissions | `AccessGate` / `AppAccessActionGate`; `inpatient-bed-management` module + role matrix from flow §13. |
| Shared UI | Reuse `lib/shared/clinical_actions` for orders and bed assignment; reuse nursing/billing panels where appropriate. |
| File size | Extract widgets to `presentation/widgets/` when `ipd_workspace_page.dart` grows; keep page compositional. |
| Tests | Add `test/features/ipd/` — controller transitions, DTO mapping, dialog flows, queue/stage mapping. |
| Backend | Extend `ipd-flow.service.js` / schemas for missing clearance and billing gates; keep stage contract stable for frontend. |

**Do not** add IPD business logic to `core/` unless genuinely cross-module.

**Reuse existing services** — analyze OPD admission handoff, emergency IPD start, nursing handover, ICU stay APIs, and clinical-order billing before adding new endpoints.

---

## Suggested Implementation Order

1. **Widget extraction + deep links** — split `ipd_workspace_page.dart`; parse `/ipd?id=&panel=` query params.
2. **Patient board polish** — critical-alert summary card, consultant/payer/LOS columns when API provides, stage label alignment with flow §11.
3. **Start admission + entry context** — wire `startAdmission`; show source encounter and admission request metadata.
4. **Bed board** — live bed list, status filters, reserve/assign/release actions.
5. **Inpatient clinical orders** — lab/radiology/pharmacy/procedure dialogs scoped to IPD encounter + billing panel.
6. **Nursing admission handoff** — checklist section or deep-link to Nursing with shared admission context.
7. **Discharge workflow** — pending-item check, multi-clearance UI, bed release after exit.
8. **Billing / insurance gates** — deposit, deferred billing, clearance integration with billing workspace.
9. **ICU bridge** — IPD detail actions or links for ICU stay start/end; critical alert resolve when not using ICU module.
10. **Backend gaps** — clearance substates, extended bed statuses, billing snapshot on admission detail if missing.
11. **Tests + quality gate** — see below.

Work in small, reviewable increments. One clear responsibility per new file.

---

## Acceptance Criteria

- [ ] Staff can open IPD workspace, filter by scope and ward, and open admission detail with live sync.
- [ ] Queue scopes and stage chips match backend contract and `../.cursor/flows/ipd-flow.mdc` §11.
- [ ] Admission desk can **start admission** and bed manager can **assign**, **transfer**, and **release** beds end-to-end.
- [ ] **Bed board** shows ward/bed status and supports allocate, reserve, and post-discharge release workflow.
- [ ] Doctors can place **lab, radiology, and medication orders** from IPD detail with pay-now/bill-later billing choice.
- [ ] Nursing admission checklist items are completable (in IPD or Nursing) with visible status on admission detail.
- [ ] **Discharge** follows multi-step clearance (summary, pharmacy, billing, nursing) before patient exit and encounter closure.
- [ ] OPD and Emergency admissions appear with source context; deep links (`/ipd?id=…&panel=…`) open the correct admission/panel.
- [ ] Billing state (deposit, deferred, clearance) is visible; no duplicate manual charges for auto-posted order items.
- [ ] Transfers record from/to location and support approve/start/complete/cancel lifecycle.
- [ ] ICU-critical patients show alerts; ICU actions are reachable without losing admission context.
- [ ] All user-facing strings localized; permissions and module entitlement enforced; no raw internal IDs in UI.
- [ ] UI provides **patient board** and **bed board** with calm, scannable layout per flow §14.
- [ ] `flutter analyze` and `flutter test` pass; new IPD tests cover repository mapping and primary workspace flows.

---

## Quality Gate

Before marking complete, run from `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run backend IPD tests from `backend/`:

```sh
npm test -- --testPathPattern=ipd-flow
```

Enable `FEATURE_IPD_WORKBENCH_V1=true` and `inpatient-bed-management` module entitlement for integration testing. Add focused tests during development; run the full gate before PR or merge.

---

## Key File References

```
.cursor/flows/ipd-flow.mdc                          # Workflow source of truth

frontend/lib/features/ipd/
├── data/dtos/ipd_dtos.dart
├── data/repositories/ipd_repository_impl.dart
├── domain/entities/ipd_entities.dart
├── domain/repositories/ipd_repository.dart
└── presentation/
    ├── controllers/ipd_workspace_controller.dart
    └── pages/ipd_workspace_page.dart

frontend/lib/features/nursing/                     # Ward checklist, handover patterns
frontend/lib/features/icu/                         # ICU board and stay actions
frontend/lib/features/billing/                     # Clearance, deposits, encounter closeout
frontend/lib/shared/clinical_actions/
├── clinical_request_billing_panel.dart
├── dialogs/clinical_admission_action_dialog.dart
├── dialogs/clinical_lab_order_action_dialog.dart
├── dialogs/clinical_radiology_order_action_dialog.dart
└── dialogs/clinical_prescription_action_dialog.dart

frontend/lib/app/router/app_router.dart            # /ipd route + deep-link handling

backend/src/modules/ipd-flow/
├── routes/ipd-flow.routes.js
├── services/ipd-flow.service.js
├── repositories/ipd-flow.repository.js
└── schemas/ipd-flow.schema.js

backend/src/modules/bed/                           # Bed catalog and status
backend/src/modules/opd-flow/services/opd-flow.service.js    # OPD → IPD handoff
backend/src/modules/emergency-case/services/emergency-case.service.js  # Emergency → IPD
backend/src/lib/clinical/ipdMedicationReminder.js
```

---

## Flow Traceability Matrix

Use this when implementing or reviewing PRs — every major deliverable should map to the flow document.

| Flow section | Topic | Primary implementation target |
|--------------|-------|-------------------------------|
| §1 | 19-step IPD workflow | End-to-end stage transitions in workspace |
| §2 | Admission entry paths | Start admission + upstream OPD/Emergency context |
| §3 | Bed management | Bed board + assign/transfer/release |
| §4 | Billing / insurance gates | Billing panels + deferred admission |
| §5 | Nursing admission | Checklist + handover with Nursing module |
| §6–§8 | Doctor care, orders, care loop | Clinical order dialogs + timeline |
| §9 | Transfers | Transfer request/update dialogs |
| §10–§12 | Discharge + statuses | Multi-step discharge clearance UI |
| §13 | Role actions | Permission gates per action |
| §14 | Patient + bed boards | Two-board workspace layout |
| §15 | Status-based actions | `AppActionList` visibility by `stage` |
| §16 | IPD encounter as hub | All panels scoped to `admissionId` / encounter |
| §17 | Turnaround improvements | Queues, realtime, early discharge prep |
| §18 | Minimal entities | Repository/DTO coverage audit |
