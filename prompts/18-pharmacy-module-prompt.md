# Pharmacy Module — Implementation Prompt

## Objective

Complete the **Pharmacy Module** for HOSSPI HMS so pharmacists can manage medication fulfillment end-to-end: receive pharmacy orders from OPD/IPD/Clinical, apply billing gates, prepare and attest dispense, manage returns, maintain stock visibility, and support **discharge take-home medicines** — linked to clinical encounters.

**Source of truth (read in this order):**

1. [flows/pharmacy-flow.mdc](../.cursor/flows/pharmacy-flow.mdc) — dispensing workflow, discharge medicines, module boundaries
2. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Pharmacy module boundaries vs Clinical, OPD, IPD, Billing, Nursing
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §3 `PHARMACY_REQUESTED` stage; §5 Pharmacy role (workspace only)
4. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §7 medication routing, §10 pharmacy clearance at discharge
5. [flows/discharge-flow.mdc](../.cursor/flows/discharge-flow.mdc) — take-home medicines clearance step

**Central encounter rule:** pharmacy orders attach to **encounter_id**. Pharmacy executes dispensing — it does not create encounters or own MAR administration (Nursing records administration on IPD).

Deliver a **professional pharmacy workbench**: dispense workflow, inventory panel, billing gate integration, and ward vs outpatient order queues.

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


## Mandatory Reading (before any Pharmacy change)

1. Re-read [flows/pharmacy-flow.mdc](../.cursor/flows/pharmacy-flow.mdc) — dispense pipeline and discharge-medicine support.
2. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Pharmacy owns drugs, orders, dispensing, returns, stock visibility.
3. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — pharmacy stage and role rules.
4. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) and [flows/discharge-flow.mdc](../.cursor/flows/discharge-flow.mdc) — ward medicines and clearance.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Pharmacy module responsibility |
| ----------- | ------------------------------ |
| `PHARMACY_REQUESTED` | Outpatient orders appear on pharmacy workbench |
| §5 Pharmacy role | Dispense workflow only — no OPD stage mutations |
| §6 UI rules | `AppWorkspace` pattern; summary cards filter queue |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Pharmacy module responsibility |
| ----------- | ------------------------------ |
| §7 Medication route | Pharmacy → ward MAR (Nursing administers) |
| §10 step 5 / §12 | Take-home medicines for discharge; `Awaiting Pharmacy Clearance` |
| §13 Pharmacy role | Issue ward meds, returns, discharge meds, clear pharmacy dues |
| §4 Billing gates | Pay-now vs bill-later on orders; deferred billing on urgent admits |
| §16 Encounter hub | Orders on IPD encounter; discharge clearance reads open orders |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Pharmacy implementation |
| ------------ | ----------------------- |
| Pharmacy row | Drugs, formulary, batches, orders, dispensing, returns, stock |
| Clinical boundary | Prescriptions created via clinical actions |
| Nursing boundary | MAR on ward — pharmacy dispenses, nursing administers |
| Billing boundary | Billing gate on orders; cashier in Billing module |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/pharmacy/` | Workbench, catalog panel, billing helpers |
| Pharmacy workspace API | `backend/src/modules/pharmacy-workspace/` | Workbench, workflow, inventory |
| Workflow | prepare-dispense, attest-dispense, cancel, return | Full dispense pipeline |
| Billing gate | `PUT /pharmacy-orders/:id` with billing payload | Pay-now / bill-later |
| Clinical intake | `clinical_prescription_action_dialog.dart` | Order creation |
| Discharge integration | Discharge module reads open pharmacy orders | Clearance context |
| Localization | `app_en.arb` | Pharmacy strings |

### Known gaps to close

- **Billing recording** — some paths bypass pharmacy-workspace via legacy order PUT.
- **Formulary/drug admin** — legacy CRUD outside workbench routes.
- **Ward vs OPD queue scopes** — explicit filters for inpatient vs outpatient orders.
- **Discharge take-home workflow** — dedicated queue for discharge-pending medications.
- **IPD clearance sync** — pharmacy clearance status on IPD/discharge detail when backend supports.
- **Frontend tests** — expand coverage for dispense and billing gate flows.
- **Large page file** — extract widgets from `pharmacy_workspace_page.dart`.

---

## Scope — Core Capabilities

### 1. Pharmacy workbench queue

- Scopes: pending prepare, ready to dispense, dispensed, returns, discharge meds.
- Patient, order ref, encounter, location (OPD/IPD), billing status, next action.

### 2. Dispense workflow

- Prepare → attest dispense with batch/stock checks.
- Cancel and return with reason capture.

### 3. Inventory and catalog

- Stock visibility, adjustments via workspace inventory routes.
- Formulary/drug reference data for dispensing.

### 4. Billing integration

- `ClinicalRequestBillingPanel` patterns at order creation (upstream).
- Workbench reflects paid vs bill-later vs pending authorization.

### 5. Discharge pharmacy clearance

- Flag orders blocking discharge; coordinate with Discharge module (ipd-flow §10–§12).
- Take-home prescription preparation before billing finalization when possible (ipd-flow §17).

---

## UI / UX Requirements

- Workspace layout: `AppWorkspace` with summary cards (filter worklist), searchable list/table, detail panel, and modal action dialogs.
- Summary cards filter the board — they must not open separate list routes.
- Hide zero-value summary cards where the workspace pattern expects it.
- Show **next required action** and **responsible role** on worklist rows where applicable.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match the Lab and Radiology executing-department workspace patterns for consistency.

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

- Do not mutate OPD/IPD flow stages from pharmacy UI.
- Do not record medication administration — Nursing owns MAR.
- Do not duplicate clinical prescribing UI in pharmacy (except pharmacist clinical review if policy allows).

---

## Acceptance Criteria

- [ ] Pharmacists complete dispense workflow on workbench APIs.
- [ ] OPD `PHARMACY_REQUESTED` clears when orders fulfilled per orchestrator.
- [ ] IPD ward and discharge orders trace to encounter.
- [ ] Billing gate respected; no duplicate charges.
- [ ] Discharge clearance can identify open pharmacy orders.
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
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
frontend/lib/features/pharmacy/
backend/src/modules/pharmacy-workspace/
frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart

Related prompts: prompts/14-clinical-module-prompt.md, prompts/22-discharge-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/09-billing-module-prompt.md
```
