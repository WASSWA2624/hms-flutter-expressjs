# Dental Module — Implementation Prompt

## Objective

Implement the **Dental Module** for HOSSPI HMS so dental officers can manage oral health care end-to-end within **outpatient and emergency workflows**: dental triage, examinations, tooth-level charting, diagnoses, procedures (fillings, extractions, scaling, root canal), dental imaging links, treatment plans, prescriptions, and follow-up visits.

**Status:** Listed in [app-write-up.mdc](../.cursor/app-write-up.mdc) but **no dedicated `features/dental/` frontend or `dental-workspace` backend exists yet**. Use this prompt when implementing from scratch.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Dental row, module boundaries, demo seed expectations
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — dental care within OPD visit; disposition and follow-up
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — inpatient dental consult on IPD encounter when admitted (rare)
4. [flows/emergency-flow.mdc](../.cursor/flows/emergency-flow.mdc) — emergency dental intake handoff to OPD when applicable

**Central rule:** dental episodes attach to the **OPD encounter** (or emergency case before handoff) unless the patient is admitted — then document on the **IPD encounter** without duplicating admission. Dental owns tooth chart and dental procedures; Clinical owns general consultation patterns; share order/billing patterns with [prompts/14-clinical-module-prompt.md](./14-clinical-module-prompt.md).

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
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/dental`, `/opd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---

## Mandatory Reading (before any Dental change)

1. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Dental row; demo dental officer, clinic unit, sample charts.
2. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — queue stages, doctor disposition, OPD completion vs admit.
3. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §16 encounter hub when inpatient dental consult is needed.
4. Review [prompts/23-physiotherapy-module-prompt.md](./23-physiotherapy-module-prompt.md) — similar specialty referral pattern from OPD disposition.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Dental module responsibility |
| ----------- | ---------------------------- |
| Dental clinic queue | Route dental officer patients; extend OPD contract with `DENTAL_REQUESTED` stage if backend adds it |
| `WAITING_DOCTOR_REVIEW` / specialty routing | Show dental worklist scoped to dental service unit |
| `WAITING_DISPOSITION` | Complete dental episode; discharge, schedule follow-up dental visit, or admit via OPD disposition |
| Orders | Dental imaging → [radiology-flow](../.cursor/flows/radiology-flow.mdc); prescriptions → [pharmacy-flow](../.cursor/flows/pharmacy-flow.mdc) via shared clinical actions |
| Billing | `ClinicalRequestBillingPanel` on billable procedures |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Dental responsibility |
| ----------- | --------------------- |
| Inpatient dental consult | Notes and orders on IPD encounter — dental does not create admission |
| Discharge | Active dental plan clearance — coordinate [discharge-flow](../.cursor/flows/discharge-flow.mdc) |

### Facility setup

- Dental clinic service unit, chairs/rooms via [prompts/03-tenant-facility-module-prompt.md](./03-tenant-facility-module-prompt.md).

---

## Current State (read before changing code)

| Area | Location | Notes |
|------|----------|-------|
| Product spec | `app-write-up.mdc` | Dental module defined; demo expectations listed |
| Frontend | **Not implemented** | No `frontend/lib/features/dental/` |
| Backend | **Not implemented** | No `dental-workspace` module; partial procedure terms in seeders |
| Related | OPD, Clinical, Radiology, Pharmacy | Reuse shared clinical order and billing patterns |

---

## Scope — Core Capabilities

### 1. Backend and schema

- Add `dental-workspace` module (or extend `opd-flow` with dental queue scope) with migrations for: `dental-chart`, `tooth-status`, `dental-procedure`, `dental-treatment-plan`.
- Anchor all records to `encounter_id` (OPD or IPD).
- RBAC + module entitlement (e.g. `dental-care`); backend authorization on all routes.

### 2. Dental workspace UI

- `AppWorkspace` with summary cards, dental patient worklist, detail panel.
- **Tooth chart** in modal or detail panel — FDI/Universal notation per facility config.
- Procedure, diagnosis, and treatment-plan dialogs (modal-first, nested confirm where needed).

### 3. Clinical integration

- Imaging and pharmacy orders via `clinical_radiology_order_action_dialog.dart` and `clinical_prescription_action_dialog.dart`.
- OPD disposition: dental follow-up without duplicate OPD encounter.

### 4. Demo seed

- Default dental officer account, dental clinic unit, sample chart entries per app-write-up Demo expectations.

---

## UI / UX Requirements

- Tooth chart: scannable, touch-friendly on mobile; minimal legend text; color only for status (healthy, treated, missing, planned).
- Worklist columns: patient, encounter ref, visit type, next action, responsible role.
- All chart edits and procedures via modals — no full-page chart routes.

---

## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | `features/dental/` with data/domain/presentation; repository → `dental-workspace` API |
| Shared UI | Reuse clinical actions, billing panel, vitals/triage components where applicable |
| Realtime | Subscribe to dental/OPD event groups when backend publishes them |

---

## Module Boundaries (do not violate)

- Do not own OPD queue orchestration — coordinate with OPD APIs for stage updates.
- Do not duplicate radiology processing or pharmacy dispensing.
- Do not create parallel patient or admission records.

---

## Acceptance Criteria

- [ ] Dental officer can chart teeth and record procedures on OPD encounter via modal workflows.
- [ ] Imaging and pharmacy orders route to existing department modules with billing choice.
- [ ] OPD disposition supports dental follow-up without duplicate encounters.
- [ ] Demo seed includes sample dental data per app-write-up.
- [ ] Module entitlement and RBAC enforced; all strings localized; `flutter analyze` and tests pass.
- [ ] Database migrations applied and documented.

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
npm test -- --testPathPattern="dental"
```

Apply database migrations per backend workflow before merging schema changes.

---

## Key File References (to create)

```
.cursor/app-write-up.mdc
backend/src/modules/dental-workspace/          # planned
frontend/lib/features/dental/                  # planned
backend/scripts/seeders/                       # dental demo data
frontend/lib/shared/clinical_actions/

Related prompts: prompts/12-opd-module-prompt.md, prompts/14-clinical-module-prompt.md, prompts/08-patients-module-prompt.md, prompts/33-demo-seed-module-prompt.md
```
