# Radiology and Imaging Module — Implementation Prompt

## Objective

Complete the **Radiology and Imaging Module** for HOSSPI HMS so radiology staff can execute imaging workflows end-to-end: receive orders from OPD/IPD/Clinical, schedule and perform studies, manage imaging assets, draft and finalize reports, sync to PACS where configured, and release results to clinicians — with billing integration at order time.

**Source of truth (read in this order):**

1. [flows/radiology-flow.mdc](../.cursor/flows/radiology-flow.mdc) — executing-department workflow and workbench contract
2. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Radiology and imaging module boundaries vs Clinical, OPD, IPD, Billing, Biomedical
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §3 `RADIOLOGY_REQUESTED` / `LAB_AND_RADIOLOGY_REQUESTED` stages; §5 Radiology role (workspace only)
4. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §7 radiology order routing, §8 care loop results review

**Central encounter rule:** every radiology order links to a **clinical encounter** (`encounter_id`). Radiology executes studies and reports on orders — it does not create OPD/IPD encounters or advance patient flow stages directly (orchestrators update OPD/IPD stages when work completes).

Deliver a **professional radiology workbench**: order-to-report pipeline, modality-aware queues, PACS/asset handling, and encounter traceability on every row.

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


## Mandatory Reading (before any Radiology change)

1. Re-read [flows/radiology-flow.mdc](../.cursor/flows/radiology-flow.mdc) — order-to-report pipeline and workbench contract.
2. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Radiology owns tests, orders, results, imaging studies, assets, PACS links.
3. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — radiology stages and role isolation.
4. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §7 imaging route and completion outputs.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Radiology module responsibility |
| ----------- | ------------------------------- |
| `RADIOLOGY_REQUESTED` | Patient has pending imaging — radiology workbench shows orders for OPD encounter |
| `LAB_AND_RADIOLOGY_REQUESTED` | Radiology completes its portion; OPD stage updated when orchestrator detects all diagnostics done |
| §5 Radiology role | Radiology workspace actions only — no OPD clinical or billing stage mutations from radiology UI |
| §6 UI rules | Reuse `AppWorkspace`, summary cards filter worklist |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Radiology module responsibility |
| ----------- | ------------------------------- |
| §7 Radiology route | Imaging queue → scan/report upload |
| §7 Order statuses | `Ordered` → `In Progress` → `Result Pending` → `Completed` / `Cancelled` on radiology order entities |
| §8 Care loop | Reports available for doctor/nurse review on IPD encounter timeline |
| §12 Service execution | Radiology is executing department — charges post per billing rules §4 |
| §16 Encounter hub | Orders, studies, results, and assets scoped to encounter/admission |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Radiology implementation |
| ------------ | ------------------------ |
| Radiology and imaging row | Tests, orders, results, studies, assets, PACS links |
| Clinical boundary | Doctors place orders via clinical actions — radiology executes |
| Billing boundary | Pay-now at order via `ClinicalRequestBillingPanel`; bill-later queues in Billing |
| Biomedical boundary | Imaging **equipment** registry/maintenance is Biomedical — radiology consumes equipment context for scheduling, not equipment PM lifecycle |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/radiology/` | Workbench, controller, repository, entities/DTOs |
| Workspace UI | `radiology_workspace_page.dart` | Patient/order views, workflow detail, study and result actions |
| Radiology workspace API | `backend/src/modules/radiology-workspace/` | Full workflow at `/api/v1/radiology/*` |
| Order pipeline | assign, start, complete, cancel; request-details update | Order lifecycle |
| Study workflow | create study, asset init/commit upload, PACS sync | Imaging capture and external links |
| Result workflow | draft, finalize, request-finalization, attest-finalization, addendum | Report lifecycle with attestation |
| Legacy CRUD | `radiology-order`, `radiology-result`, `radiology-test`, `imaging-study`, `imaging-asset`, `pacs-link` | Catalog and granular resources |
| Clinical intake | `clinical_radiology_order_action_dialog.dart` | Order creation with billing |
| Catalog admin | Repository CRUD on `/radiology-tests` | Facility catalog configuration |
| Equipment read | `listEquipmentRecords` via equipment registries | Scheduling/equipment context |
| Backend tests | `backend/src/tests/modules/radiology-workspace/` | Controller, service, schema coverage |
| Localization | `app_en.arb` | Radiology workspace strings |

### Known gaps to close

- **Flow orchestration** — no direct opd-flow/ipd-flow API calls; stage transitions depend on order completion hooks — verify integration with OPD `RADIOLOGY_*` stages.
- **Combined diagnostics** — when both lab and radiology pending (`LAB_AND_RADIOLOGY_REQUESTED`), workbench should not assume exclusive queues; confirm orchestrator clears stage only when both complete.
- **PACS integration** — `pacs-sync` exists; UI may need polish for failure/retry and link display on clinical detail.
- **Asset upload** — init/commit upload flow; verify platform-specific upload UX and preview on report detail.
- **Encounter context on rows** — show OPD vs IPD source, ward/bed when inpatient.
- **Result attestation** — request-finalization / attest-finalization roles and visibility per facility policy.
- **Catalog vs clinical catalog** — align facility radiology test catalog with `clinical_catalog` / shared radiology catalog helpers.
- **Frontend tests** — expand widget/controller coverage (mirror lab module test depth).
- **Large page file** — extract widgets from `radiology_workspace_page.dart` per project conventions.

---

## Scope — Core Capabilities

### 1. Radiology workbench queue

- Filter by workflow stage, modality, status; toggle **patients** vs **orders** view (`view=PATIENTS|ORDERS`).
- Summary cards filter worklist; show patient, order ID, modality, tests, encounter ref, priority, next action.

**Reference APIs:** `GET /radiology/workbench`, `GET /radiology/reference-data`.

### 2. Order lifecycle

- Create order (from clinical upstream or radiology desk when permitted).
- **Assign** technologist/room/equipment → **start** study → **complete** order.
- Update request details; **cancel** with reason.

**Reference APIs:** `POST /radiology/orders`, `POST /radiology/orders/:id/assign|start|complete|cancel`, `PUT /radiology/orders/:id/request-details`, `GET /radiology/orders/:id/workflow`.

### 3. Imaging studies and assets

- Create study on order; upload imaging assets (init-upload → commit-upload).
- **PACS sync** when facility has PACS configured; show PACS link on result/study detail.
- Delete assets when policy allows; audit trail on mutations.

**Reference APIs:** `POST /radiology/orders/:id/studies`, `POST /radiology/studies/:id/assets/init-upload|commit-upload`, `POST /radiology/studies/:id/pacs-sync`.

### 4. Reporting and release

- **Draft** report → **finalize** or **request-finalization** → **attest-finalization** (two-step sign-off when required).
- **Addendum** for corrected/additional reports after finalization.
- Released reports visible on Clinical/IPD/OPD timelines via realtime events.

**Reference APIs:** `POST /radiology/orders/:id/results/draft`, `POST /radiology/results/:id/finalize|request-finalization|attest-finalization|addendum`.

### 5. Billing alignment

- Reflect pay-now vs bill-later from order billing payload at clinical order time.
- Do not duplicate charge capture in radiology UI.

### 6. Order intake (upstream)

- Orders arrive from Clinical/OPD with `encounter_id` — radiology does not re-enter clinical indication.
- OPD `opdRouteRadiologyAction` routes patient to radiology stage — workbench receives orders, does not mutate OPD stage from radiology UI.

---

## UI / UX Requirements

- Workspace layout: `AppWorkspace` with summary cards (filter worklist), searchable list/table, detail panel, and modal action dialogs.
- Summary cards filter the board — they must not open separate list routes.
- Hide zero-value summary cards where the workspace pattern expects it.
- Show **next required action** and **responsible role** on worklist rows where applicable.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match Lab, Pharmacy, and OPD workspace patterns for consistency.

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

- Do not mutate OPD stages or IPD admission stages from radiology UI.
- Do not own clinical diagnosis or inpatient discharge.
- Do not run cashier workflows — billing desk settles deferred charges.
- Do not own biomedical equipment PM — link to equipment registry for scheduling only.

---

## Acceptance Criteria

- [ ] Radiology staff can process orders from assign through report finalization on workbench APIs.
- [ ] Studies, assets, and PACS sync work when facility is configured.
- [ ] Orders trace to OPD/IPD encounters on every row.
- [ ] OPD `RADIOLOGY_*` and `LAB_AND_RADIOLOGY_REQUESTED` stages clear when orchestrator detects completion.
- [ ] IPD care loop receives reports for doctor review.
- [ ] Billing choice at order time reflected in invoice state.
- [ ] Attestation/addendum flows respect role permissions.
- [ ] Workbench actions run in dialogs/sheets (no workflow routing); rows, detail, and summary cards refresh via realtime sync, and finalized reports surface on clinical timelines.
- [ ] No raw UUIDs; permissions enforced; tests pass.

---

## Quality Gate

Before marking complete, run from `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run backend radiology tests from `backend/`:

```sh
npm test -- --testPathPattern=radiology-workspace
```

Apply database migrations per backend workflow before merging schema changes.

---

## Key File References

```
.cursor/flows/opd-flow.mdc
.cursor/flows/ipd-flow.mdc
.cursor/app-write-up.mdc

frontend/lib/features/radiology/
backend/src/modules/radiology-workspace/
frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart
frontend/lib/shared/clinical_actions/clinical_radiology_catalog_helpers.dart

Related prompts: prompts/14-clinical-module-prompt.md, prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/16-lab-module-prompt.md, prompts/09-billing-module-prompt.md
```
