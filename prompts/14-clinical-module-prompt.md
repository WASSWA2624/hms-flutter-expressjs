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

## UI / UX Requirements

- Workspace layout: `AppWorkspace` with summary cards (filter worklist), searchable list/table, detail panel, and modal action dialogs.
- Summary cards filter the board — they must not open separate list routes.
- Hide zero-value summary cards where the workspace pattern expects it.
- Show **next required action** and **responsible role** on worklist rows where applicable.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match Nursing, IPD, Lab, and OPD workspace patterns for consistency.

---


## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → Riverpod controllers → repository interface → impl → API client. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure` for errors. |
| Permissions | `AccessGate` / `AppAccessActionGate`; backend auth mandatory even when UI hides actions. |
| File size | Extract reusable widgets to `presentation/widgets/`; shared components to `frontend/lib/shared/`. |
| Realtime | `frontend/.cursor/realtime_sync.mdc` — partial refresh after modal success when supported. |

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

## Quality Gate

From `frontend/` when touching Flutter:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
frontend/lib/features/clinical/
frontend/lib/shared/clinical_actions/
backend/src/modules/clinical-note/, lab-order/, pharmacy-order/, radiology-order/
backend/src/modules/opd-flow/, ipd-flow/

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/16-lab-module-prompt.md, prompts/18-pharmacy-module-prompt.md, prompts/17-radiology-module-prompt.md
```
