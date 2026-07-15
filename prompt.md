# Make OPD Flow "Next Step" Actions Navigable and Fix Cross-Module Consistency

## Objective

Ensure that every "next step" or "current step" indicator across all modules (Reception, OPD, Billing, IPD, ICU, Nursing, Clinical, Pharmacy, Radiology, Laboratory, etc.) is an actionable button that routes the user directly to the exact page, dialog, or module where the step can be completed. Additionally, fix data inconsistencies and make Reception tabs URL-routable.

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

### 3. Convert "Next step" into an actionable navigation button

For every module's table that displays a "next step", "current step", or equivalent status column:

- Render the value as a **clickable button or chip** (styled distinctly from plain text — e.g. teal/primary color, underline, or icon-adorned).
- On click, the button must **navigate the user to the exact module, page, or dialog** where the action can be completed.
- The routing logic should be centralized — a single `resolveNextStepRoute(stepType, context)` utility that maps step identifiers to their target routes/dialogs.

**Example mappings:**

| Step identifier | Target route / action |
|---|---|
| `pay_consultation` | Navigate to `/billing` with encounter pre-filtered, or open payment dialog inline |
| `start_encounter` | Navigate to the clinical workspace for the encounter |
| `triage` | Navigate to nursing triage form for the encounter |
| `assign_doctor` | Open doctor assignment dialog |
| `lab_order` | Navigate to `/laboratory` with the pending order |
| `dispense_medication` | Navigate to `/pharmacy` with the prescription |

- This must work **regardless of which module the user is currently viewing**. Whether in Reception, OPD, Billing, or Nursing — clicking the next step button always takes the user to the correct destination.

### 4. Ensure Billing queue is populated from OPD consultation fees

- When an encounter reaches the "pay consultation" step, a billing item / invoice must be created and appear in the Billing module's queue.
- The billing item should reference the encounter, patient, assigned doctor, and the consultation fee amount.
- Until payment is completed, the item remains visible in the Billing queue with "Payment due" status.

### 5. Improve status label clarity

- Replace vague "In Progress" with contextual status text that reflects the actual current activity (e.g. "Awaiting payment", "In triage", "With doctor", "Awaiting lab results").
- Ensure status text is consistent across all modules for the same encounter state.

---

## Implementation Approach

### Central "Next Step" resolver

Create a shared utility/service that:
1. Accepts a step type/identifier and encounter context.
2. Returns the appropriate navigation action (route path, dialog builder, or deep-link URL).
3. Is consumed by all module tables that render "next step" or "current step" columns.

### Billing item creation

Ensure the OPD flow service creates a billing/invoice record when the encounter transitions to the payment step. The backend endpoint that advances the encounter step should also trigger billing item creation if one doesn't already exist.

---

## Files Likely Affected

| Area | Files / Modules |
|---|---|
| Reception page routing | `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` |
| Active visits data mapping | Reception controller/provider mapping encounter fields to table columns |
| Next step button widget | New shared widget: `NextStepActionButton` or similar |
| Step → route resolver | New shared utility: `next_step_resolver.dart` or equivalent |
| OPD flow table | `frontend/lib/features/opd/presentation/` — OPD table column definitions |
| Billing queue population | `backend/src/modules/billing/` — invoice/billing item creation |
| OPD flow service | `backend/src/modules/opd-flow/services/opd-flow.service.js` — step transition logic |
| Status label mapping | Shared enum/constants mapping step states to human-readable labels |

---

## Technical Constraints

- **URL-driven state**: Tab selection and deep-linking must work with browser back/forward navigation.
- **Cross-module navigation**: The next-step resolver must handle routing across module boundaries without circular dependencies.
- **Backend consistency**: Billing items must be created atomically with step transitions (or via an event/hook) to prevent orphaned states where a patient is "awaiting payment" but no billing item exists.
- **No regressions**: All existing table interactions (sorting, searching, pagination, row click navigation) must continue working.
- **Accessibility**: Action buttons must be keyboard-accessible with clear focus indicators and ARIA labels.
