# Discharge Module — Implementation Prompt

## Objective

Complete the **Discharge Module** for HOSSPI HMS so doctors, nurses, pharmacists, billers, and discharge coordinators can run **multi-step inpatient discharge** end-to-end: discharge planning, pending-order checks, summary preparation, pharmacy clearance, billing finalization, nursing clearance, patient exit, bed release handoff, and encounter closure — anchored to the **IPD encounter**.

**Source of truth (read in this order):**

1. [flows/discharge-flow.mdc](../.cursor/flows/discharge-flow.mdc) — multi-step clearance orchestration (primary flow spec)
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §10–§12 discharge workflow, §12 discharge statuses, §15 role actions, §16 encounter hub
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §3 contrast: OPD `DISCHARGED` completes outpatient visit only
4. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Discharge vs Billing, Pharmacy, Nursing, Mortuary boundaries

**Central encounter rule:** discharge clearance attaches to the **IPD admission / encounter**. Discharge does not create parallel records; it orchestrates clearance across departments on the same admission.

Deliver a **calm clearance workspace**: queue of patients in `DISCHARGE_PLANNED` and clearance substates, checklist visibility per role, and handoff to Housekeeping after bed release.

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


## Mandatory Reading (before any Discharge change)

1. Re-read [flows/discharge-flow.mdc](../.cursor/flows/discharge-flow.mdc) — clearance steps, status mapping, module boundaries.
2. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — discharge mermaid flow §10, steps table, `DISCHARGE_PLANNED` / `DISCHARGED` stages.
3. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §8 completion; do not confuse OPD visit closure with IPD discharge.
4. Re-read [flows/pharmacy-flow.mdc](../.cursor/flows/pharmacy-flow.mdc) and [flows/nursing-flow.mdc](../.cursor/flows/nursing-flow.mdc) — clearance handoffs.
5. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Discharge vs Billing vs Pharmacy vs Nursing vs Mortuary (death pathway).

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

## UI / UX Requirements

- Workspace layout: `AppWorkspace` with summary cards (filter worklist), searchable list/table, detail panel, and modal action dialogs.
- Summary cards filter the board — they must not open separate list routes.
- Hide zero-value summary cards where the workspace pattern expects it.
- Show **next required action** and **responsible role** on worklist rows where applicable.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match the IPD and Nursing workspace patterns for consistency (same admission encounter and clearance semantics).

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


## Acceptance Criteria

- [ ] Queue shows IPD patients in discharge stages per ipd-flow §10–§12.
- [ ] Plan and finalize discharge work end-to-end via ipd-flow APIs.
- [ ] Clearance checklist reflects pharmacy, billing, nursing, doctor status.
- [ ] Bed release / housekeeping handoff documented or wired after exit.
- [ ] OPD `DISCHARGED` not conflated with IPD discharge in UI copy.
- [ ] No raw UUIDs; permissions enforced; tests added for primary flows.

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
.cursor/flows/ipd-flow.mdc
frontend/lib/features/discharge/
backend/src/modules/ipd-flow/
backend/src/modules/discharge-summary/

Related prompts: prompts/19-ipd-module-prompt.md, prompts/09-billing-module-prompt.md, prompts/18-pharmacy-module-prompt.md, prompts/15-nursing-module-prompt.md, prompts/27-housekeeping-module-prompt.md
```
