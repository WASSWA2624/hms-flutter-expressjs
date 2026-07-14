# Laboratory Module — Implementation Prompt

## Objective

Complete the **Laboratory Module** for HOSSPI HMS so lab staff can execute diagnostic workflows end-to-end: receive orders from OPD/IPD/Clinical, collect samples, process tests, enter and verify results, handle QC, and release results to clinicians — with billing integration at order time.

**Source of truth (read in this order):**

1. [flows/lab-flow.mdc](../.cursor/flows/lab-flow.mdc) — executing-department workflow, workbench contract, module boundaries
2. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Laboratory module boundaries vs Clinical, OPD, IPD, Billing
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §3 `LAB_REQUESTED` / `LAB_AND_RADIOLOGY_REQUESTED` stages; §5 Lab role (workspace only)
4. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §7 lab order routing, §8 care loop, §17 critical-result notification

**Central encounter rule:** every lab order links to a **clinical encounter** (`encounter_id`). Lab executes and reports on orders — it does not create OPD/IPD encounters or advance patient flow stages directly (orchestrators update OPD/IPD stages when work completes).

Deliver a **professional lab workbench**: sample-to-result pipeline, queue by workflow stage, critical result handling, and encounter traceability on every row.

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


## Mandatory Reading (before any Lab change)

1. Re-read [flows/lab-flow.mdc](../.cursor/flows/lab-flow.mdc) — sample-to-result pipeline and workbench contract.
2. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Lab owns tests, orders, samples, results, QC.
3. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — lab stages and role isolation.
4. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §7 order routing and completion outputs.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Lab module responsibility |
| ----------- | ------------------------- |
| `LAB_REQUESTED` | Patient has pending lab work — lab workbench shows orders for OPD encounter |
| `LAB_AND_RADIOLOGY_REQUESTED` | Lab completes its portion; OPD stage updated when orchestrator detects all diagnostics done |
| §5 Lab role | Lab workspace actions only — no OPD clinical or billing stage mutations from lab UI |
| §6 UI rules | Reuse `AppWorkspace`, summary cards filter worklist |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Lab module responsibility |
| ----------- | ------------------------- |
| §7 Lab test route | Sample collection → processing → result upload |
| §7 Order statuses | `Ordered` → `In Progress` → `Completed` / `Cancelled` on lab order entities |
| §8 Care loop | Results available for doctor/nurse review on IPD encounter timeline |
| §12 Service execution | Lab is executing department — charges post per billing rules §4 |
| §16 Encounter hub | Orders and results scoped to encounter/admission |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Lab implementation |
| ------------ | ------------------ |
| Laboratory row | Tests, panels, orders, samples, results, QC |
| Clinical boundary | Doctors place orders via clinical actions — lab executes |
| Billing boundary | Pay-now at order via `ClinicalRequestBillingPanel`; bill-later queues in Billing |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/lab/` | Workbench, result entry dialog, controller, repository |
| Lab workspace API | `backend/src/modules/lab-workspace/` | `GET /lab/workbench`, workflow mutations |
| Order pipeline | collect, receive/reject sample, release/reject result, verify, reverse | End-to-end workflow routes |
| Legacy CRUD | `lab-order`, `lab-test`, `lab-panel`, `lab-result`, `lab-qc-log` | Catalog and admin |
| Clinical intake | `clinical_lab_order_action_dialog.dart` | Order creation with billing |
| Backend tests | `backend/src/tests/modules/lab-workspace/` | Strong coverage |
| Localization | `app_en.arb` | Lab workspace strings |

### Known gaps to close

- **Flow orchestration** — no direct opd-flow/ipd-flow API calls; stage transitions depend on order completion hooks — verify integration.
- **Catalog/QC UI** — admin catalog and QC may use legacy endpoints outside workbench.
- **Critical results** — notify doctor/ward when critical values released (ipd-flow §17).
- **Encounter context on rows** — show OPD vs IPD source, ward/bed when inpatient.
- **Frontend tests** — expand widget/controller coverage.
- **Large page file** — extract widgets from `lab_workspace_page.dart`.

---

## Scope — Core Capabilities

### 1. Lab workbench queue

- Filter by workflow stage: pending collection, in lab, result entry, verification, released.
- Summary cards filter worklist; show patient, order ID, tests, encounter ref, priority.

### 2. Sample and processing workflow

- `POST /lab/orders/:id/collect`
- Sample receive/reject; item-level result entry and release.
- Order-level verify and reverse with audit trail.

### 3. Results and clinical notification

- Released results visible on Clinical/IPD/OPD timelines via realtime events.
- Critical flag handling per facility policy.

### 4. Billing alignment

- Reflect pay-now vs bill-later from order billing payload.
- Do not duplicate charge capture in lab UI.

### 5. Order intake (upstream)

- Orders arrive from Clinical/OPD with `encounter_id` — lab does not re-enter clinical indication.

---

## UI / UX Requirements

- Workspace layout: `AppWorkspace` with summary cards (filter worklist), searchable list/table, detail panel, and modal action dialogs.
- Summary cards filter the board — they must not open separate list routes.
- Hide zero-value summary cards where the workspace pattern expects it.
- Show **next required action** and **responsible role** on worklist rows where applicable.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match Radiology, Pharmacy, and OPD workspace patterns for consistency.

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

- Do not mutate OPD stages or IPD admission stages from lab UI.
- Do not own clinical diagnosis or inpatient discharge.
- Do not run cashier workflows — billing desk settles deferred charges.

---

## Acceptance Criteria

- [ ] Lab staff can process orders sample-to-result on workbench APIs.
- [ ] Orders trace to OPD/IPD encounters on every row.
- [ ] OPD `LAB_*` stages clear when backend orchestrator detects completion.
- [ ] IPD care loop receives results for doctor review.
- [ ] Billing choice at order time reflected in invoice state.
- [ ] Workbench actions run in dialogs/sheets (no workflow routing); rows, detail, and summary cards refresh via realtime sync, and released results surface on clinical timelines.
- [ ] No raw UUIDs; permissions enforced; tests pass.

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
npm test -- --testPathPattern="lab-workspace|lab-order"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
.cursor/flows/lab-flow.mdc
frontend/lib/features/lab/
backend/src/modules/lab-workspace/
frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart

Related prompts: prompts/14-clinical-module-prompt.md, prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/09-billing-module-prompt.md, prompts/17-radiology-module-prompt.md
```
