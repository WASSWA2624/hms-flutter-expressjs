# Pharmacy Module — Implementation Prompt

## Objective

Complete the **Pharmacy Module** for HOSSPI HMS so pharmacists can manage medication fulfillment end-to-end: receive pharmacy orders from OPD/IPD/Clinical, apply billing gates, prepare and attest dispense, manage returns, maintain stock visibility, and support **discharge take-home medicines** — linked to clinical encounters.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Pharmacy module boundaries vs Clinical, OPD, IPD, Billing, Nursing
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §3 `PHARMACY_REQUESTED` stage; §5 Pharmacy role (workspace only)
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §7 medication routing, §10 pharmacy clearance at discharge, §12 `Medication Pending`, §13 pharmacy role actions

**Central encounter rule:** pharmacy orders attach to **encounter_id**. Pharmacy executes dispensing — it does not create encounters or own MAR administration (Nursing records administration on IPD).

Deliver a **professional pharmacy workbench**: dispense workflow, inventory panel, billing gate integration, and ward vs outpatient order queues.

---

## Mandatory Reading (before any Pharmacy change)

1. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Pharmacy owns drugs, orders, dispensing, returns, stock visibility.
2. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — pharmacy stage and role rules.
3. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — ward medicines, discharge medicines, clearance.

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

## Key File References

```
frontend/lib/features/pharmacy/
backend/src/modules/pharmacy-workspace/
frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart

Related prompts: prompts/03-clinical-module-prompt.md, prompts/08-discharge-module-prompt.md, prompts/05-ipd-module-prompt.md, prompts/12-billing-module-prompt.md
```
