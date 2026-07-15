# Universal "Next Step" Navigation — All Patient Flows

## Objective

Implement a system-wide "next step" navigation pattern so that **every** workflow in the application — OPD, IPD, ICU, Emergency, Nursing, Clinical (Doctors), Pharmacy, Laboratory, Radiology, Billing, Physiotherapy, Operating Theater, Discharge Planning — presents a clear, clickable action button that instantly routes the user to the exact page, dialog, or module where the next step must be completed. The user should never have to guess where to go or what to do next. Additionally, fix data inconsistencies and make Reception tabs URL-routable.

---

## Current State (Problems Identified)

### 1. Reception tabs are not URL-routable

**Location:** `/reception`

The four tabs — Appointments, Desk queue, Active visits, Payment gate — do not update the browser URL when selected. Deep-linking (e.g. `/reception?tab=payment-gate`) is not supported.

### 2. Patient ID column shows Encounter ID on Active Visits

**Location:** Reception → Active visits tab

The "Patient ID" column displays `ENC0000003` (an encounter identifier) instead of the actual patient ID (`PAT0000001`). This is a data mapping error.

### 3. "Next step" / "Current step" labels are informational only — not actionable

**Locations observed:**
- Reception → Active visits: "Current step" column shows "Payment due" as plain text.
- Reception → Payment gate: "Current step" shows "Payment due" with no link.
- OPD flow (`/opd`): "Next step" column shows "Pay consultation" as plain text.

**Expected behaviour:** Each "next step" value should be a clickable button/link that navigates the user to the exact location where that step is completed. For "Pay consultation", clicking should route to the Billing module (or open an inline payment dialog) with the relevant encounter pre-loaded.

### 4. Billing module shows no items despite pending payments

**Location:** `/billing`

Even though the patient has "Payment due" status in both Reception and OPD, the Billing page displays "No billing items — No invoices or billing actions in this queue." The billing queue is not being populated from the OPD flow's consultation fee requirement.

### 5. Status labels are vague and inconsistent across modules

| Module | Column | Value shown | Problem |
|--------|--------|-------------|---------|
| Reception → Appointments | Status | "In Progress" | Doesn't indicate *what* is in progress |
| Reception → Desk queue | Status | "In Progress" | Same vague label |
| Reception → Active visits | Current step | "Payment due" | Informational but not actionable |
| OPD flow | Queue status | "Payment due" | Duplicate info, still not actionable |
| OPD flow | Next step | "Pay consultation" | Descriptive but no navigation path |

---

## Target Design

### 1. Make Reception tabs URL-routable

- Selecting a tab must update the URL query parameter (e.g. `/reception?tab=appointments`, `/reception?tab=desk-queue`, `/reception?tab=active-visits`, `/reception?tab=payment-gate`).
- Direct navigation to these URLs must select the correct tab on page load.
- Follow the same pattern already used in other routable tabs in the app (e.g. Admin Access page with `panel` query param).

### 2. Fix Patient ID mapping on Active Visits

- The "Patient ID" column in the Active visits tab must show the patient's actual ID (e.g. `PAT0000001`), not the encounter ID.
- If both are needed, add a separate "Encounter ID" column or show the encounter ID in a secondary/detail row.

### 3. Convert "Next step" into an actionable navigation button — across ALL flows

This is not limited to OPD. **Every module** that participates in a patient workflow must render its "next step" / "current step" / "next action" column as a clickable, clearly styled button that navigates the user to the exact destination.

**Principle:** No matter which module or page the user is on, if a row shows a pending next action, one click should take the user directly there. The user never guesses, never hunts through the sidebar, never has to know which module "owns" the next step.

For every module's table that displays a "next step", "current step", or equivalent status column:

- Render the value as a **clickable button or chip** (styled distinctly from plain text — e.g. teal/primary color, underline, or icon-adorned).
- On click, the button must **navigate the user to the exact module, page, or dialog** where the action can be completed.
- The routing logic should be centralized — a single `resolveNextStepRoute(stepType, context)` utility that maps step identifiers to their target routes/dialogs.

**Example mappings (comprehensive across all flows):**

| Step identifier | Flow(s) | Target route / action |
|---|---|---|
| `pay_consultation` | OPD, Emergency | Navigate to `/billing` with encounter pre-filtered, or open payment dialog inline |
| `start_encounter` | OPD, IPD, Emergency | Navigate to the clinical workspace for the encounter |
| `triage` | OPD, Emergency, IPD | Navigate to nursing triage form for the encounter |
| `assign_doctor` | OPD, IPD, ICU | Open doctor assignment dialog |
| `lab_order` | Clinical, OPD, IPD, ICU | Navigate to `/laboratory` with the pending order |
| `lab_results_ready` | Laboratory | Navigate to clinical workspace to review results |
| `dispense_medication` | Pharmacy | Navigate to `/pharmacy` with the prescription |
| `radiology_scan` | Clinical, OPD, IPD | Navigate to `/radiology` with the imaging request |
| `radiology_report_ready` | Radiology | Navigate to clinical workspace to review report |
| `admit_patient` | Emergency, OPD | Navigate to IPD admission form |
| `assign_bed` | IPD, ICU | Navigate to `/rooms-beds` with patient context |
| `nursing_assessment` | Nursing, IPD, ICU | Navigate to nursing assessment form |
| `surgery_scheduling` | Clinical, IPD | Navigate to `/operating-theater` scheduling |
| `discharge_planning` | IPD, ICU | Navigate to `/discharge-planning` with encounter |
| `physiotherapy_session` | Clinical, IPD | Navigate to physiotherapy module |
| `insurance_preauth` | Billing | Navigate to `/insurance-claims` pre-authorization form |
| `close_encounter` | OPD, Emergency | Complete and close the encounter |

- This must work **regardless of which module the user is currently viewing**. Whether in Reception, OPD, Billing, Nursing, IPD, ICU, Laboratory, Pharmacy, Radiology, or any other module — clicking the next step button always takes the user to the correct destination.
- The system should detect the appropriate next step based on the encounter's current state and workflow configuration, then present it as a single clear call-to-action.

### 4. Ensure Billing queue is populated from ALL flows that require payment

- When **any** encounter (OPD, IPD, ICU, Emergency, etc.) reaches a payment step, a billing item / invoice must be created and appear in the Billing module's queue.
- The billing item should reference the encounter, patient, assigned staff, service type, and the fee amount.
- Until payment is completed, the item remains visible in the Billing queue with "Payment due" status.
- This applies to consultation fees, lab fees, radiology fees, pharmacy charges, procedure fees, bed charges, etc. — any billable step across any flow.

### 5. Improve status label clarity

- Replace vague "In Progress" with contextual status text that reflects the actual current activity (e.g. "Awaiting payment", "In triage", "With doctor", "Awaiting lab results").
- Ensure status text is consistent across all modules for the same encounter state.

---

## Implementation Approach

### Central "Next Step" resolver (shared across all modules)

Create a shared utility/service that:
1. Accepts a step type/identifier and encounter context (encounter ID, patient ID, flow type, assigned staff, etc.).
2. Returns the appropriate navigation action (route path, dialog builder, or deep-link URL).
3. Is consumed by **all** module tables that render "next step" or "current step" columns — OPD, IPD, ICU, Emergency, Nursing, Clinical, Pharmacy, Lab, Radiology, Billing, Operating Theater, Discharge Planning, Physiotherapy.
4. Handles edge cases: if the next step requires a different user role (e.g. only a doctor can start a consultation), show the button but indicate it's assigned to another role/person.

### Shared "NextStepActionButton" widget

A single reusable widget used in every module's table:
- Displays the human-readable step label.
- Styled as a clear call-to-action (not plain text).
- On tap, calls the central resolver and navigates accordingly.
- Shows a tooltip or subtitle indicating which module/area it will navigate to (e.g. "Opens in Billing").

### Billing item creation (all flows)

Ensure that **every** flow service (OPD, IPD, ICU, Emergency, etc.) creates a billing/invoice record when the encounter transitions to any payment step. The backend endpoint that advances the encounter step should also trigger billing item creation if one doesn't already exist.

### Step state synchronization

All modules must read from and write to the same encounter step state. When a step is completed in one module (e.g. payment completed in Billing), all other modules displaying that encounter (Reception, OPD, etc.) must immediately reflect the updated status and advance to the next step.

---

## Files Likely Affected

| Area | Files / Modules |
|---|---|
| Reception page routing | `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` |
| Active visits data mapping | Reception controller/provider mapping encounter fields to table columns |
| Next step button widget | New shared widget: `NextStepActionButton` — used in ALL module tables |
| Step → route resolver | New shared utility: `next_step_resolver.dart` — central routing logic |
| OPD flow table | `frontend/lib/features/opd/presentation/` — table column definitions |
| IPD flow table | `frontend/lib/features/ipd/presentation/` — table column definitions |
| ICU flow table | `frontend/lib/features/icu/presentation/` — table column definitions |
| Emergency flow table | `frontend/lib/features/emergency/presentation/` — table column definitions |
| Nursing module table | `frontend/lib/features/nursing/presentation/` — table column definitions |
| Clinical (Doctors) table | `frontend/lib/features/clinical/presentation/` — table column definitions |
| Pharmacy module table | `frontend/lib/features/pharmacy/presentation/` — table column definitions |
| Laboratory module table | `frontend/lib/features/laboratory/presentation/` — table column definitions |
| Radiology module table | `frontend/lib/features/radiology/presentation/` — table column definitions |
| Billing queue population | `backend/src/modules/billing/` — invoice/billing item creation from all flows |
| OPD flow service | `backend/src/modules/opd-flow/services/opd-flow.service.js` — step transition logic |
| All flow services (backend) | Every flow service that manages encounter step transitions |
| Status label mapping | Shared enum/constants mapping step states to human-readable labels |

---

## Technical Constraints

- **URL-driven state**: Tab selection and deep-linking must work with browser back/forward navigation.
- **Cross-module navigation**: The next-step resolver must handle routing across module boundaries without circular dependencies. Use a registry pattern or route map — not direct imports between feature modules.
- **Backend consistency**: Billing items must be created atomically with step transitions (or via an event/hook) to prevent orphaned states where a patient is "awaiting payment" but no billing item exists.
- **All flows, not just OPD**: The implementation must cover OPD, IPD, ICU, Emergency, Nursing, Clinical, Pharmacy, Laboratory, Radiology, Operating Theater, Discharge Planning, Physiotherapy, and Billing. Every module that displays a patient's workflow state must use the shared `NextStepActionButton`.
- **Scalability**: Adding a new flow step in the future should only require registering the step identifier and its target route in the central resolver — no changes to individual module tables.
- **Real-time updates**: When a step is completed in any module, all other modules showing that encounter must reflect the change (via WebSocket, polling, or Riverpod state invalidation).
- **No regressions**: All existing table interactions (sorting, searching, pagination, row click navigation) must continue working.
- **Accessibility**: Action buttons must be keyboard-accessible with clear focus indicators and ARIA labels.


