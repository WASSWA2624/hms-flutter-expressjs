# Clinical Lab Request → Billing Office Payment

## Objective

When a clinician **submits a lab request**, the charge must immediately appear in the **Billing workspace** so billers can collect payment at the billing office. Payment is **never** handled at order submission — the clinician only requests tests; the billing desk owns payment and clearance.

Once a biller marks a charge **paid / cleared**, that status must be **globally visible** across the system (billing, lab workbench, and any other module that shows the order) so all relevant staff know whether payment is pending or complete.

## Workflow

```
Clinician submits lab request
        ↓
Charge created → visible in Billing workspace (pending clearance)
        ↓
Patient pays at billing office
        ↓
Biller opens bill detail → marks as paid / cleared
        ↓
Clearance status updates everywhere (billing, lab, clinical views)
```



## Clinician side (order submission)

- Clinician selects tests/panels and submits — **no payment step** in the lab order dialog.
- Backend creates the lab order and linked billing charge via `applyClinicalRequestBilling` (`backend/src/lib/billing/clinical-request-billing.js`).
- Initial clearance state: **pending** (awaiting payment at billing office).



## Billing workspace — worklist

Billers must see **every submitted lab-linked charge**, not only a subset.

Each row shows:


| Field            | Notes                                                   |
| ---------------- | ------------------------------------------------------- |
| Patient name     | Human-readable name                                     |
| Patient ID       | Display ID / patient number — not raw UUID              |
| Encounter        | Encounter the bill belongs to                           |
| Amount           | Total charge for the request                            |
| Clearance status | **Pending** or **Paid / cleared** — single global state |


Reuse `billing_workspace_page.dart`, `BillingWorkItem`, and existing clearance chips (`BillingClearanceState`).

Default queue filter: **Awaiting payment** (`PENDING_PAYMENT`).

## Billing workspace — row detail (dialog)

Clicking a worklist row opens a **detail dialog** (modal — no new route) showing:

- Patient and encounter context
- Line items (tests/panels) and total amount
- Current clearance status
- Payment method and reference (when recording payment)
- Primary action: **Mark as paid / cleared** (via existing receive-payment flow, `billingWrite`)

Billers may record payment and confirm clearance; they **must not** change the billed amount set at order submission.

## Global clearance visibility

Payment status is **one source of truth** on the linked invoice / billing snapshot (`billing_snapshot` on the lab order).


| Role / module             | What they see                                                                 |
| ------------------------- | ----------------------------------------------------------------------------- |
| Billing                   | Worklist row + detail; can mark paid / cleared                                |
| Lab personnel             | Order row/detail shows clearance badge (pending vs paid / cleared) and amount |
| Clinical / OPD / IPD, etc | Same pending / cleared indicator where the order is referenced                |


After a biller marks a charge cleared:

- Billing work item moves out of **Awaiting payment** (or shows paid state).
- Lab workbench reflects updated `payment_status` / clearance on the order without manual refresh beyond normal realtime sync (`RealtimeEventGroups.billingWorkspace`, billing domain events).
- No module may show a conflicting payment state.



## Permissions


| Role                    | Can do                                             | Cannot do                             |
| ----------------------- | -------------------------------------------------- | ------------------------------------- |
| Clinician               | Submit lab request                                 | Collect payment or mark bills cleared |
| Biller (`billingWrite`) | View charges, receive payment, mark paid / cleared | Override billed line-item amounts     |
| Lab staff               | View clearance status on orders                    | Mark payment or change amounts        |




## Out of scope

- Point-of-care payment in the lab order dialog (remove or hide pay-now path for lab orders if still present).
- Lab execution (sample collection, results entry).
- Adjustments, refunds, or voids outside existing approval flows.



## References

- Billing: `frontend/lib/features/billing/`, `prompts/09-billing-module-prompt.md`
- Lab orders: `clinical_lab_order_action_dialog.dart`, `lab_workspace_page.dart`, `prompts/16-lab-module-prompt.md`
- Billing apply / snapshot: `backend/src/lib/billing/clinical-request-billing.js`
- Order-time billing UI (to simplify): `clinical_request_billing_panel.dart`, `clinical_request_billing_state.dart`



## Acceptance criteria

1. Clinician submits a lab request with no payment UI → charge appears in Billing workspace as **pending** within one refresh cycle.
2. Worklist row shows patient name, patient ID, encounter, amount, and clearance status.
3. Row click opens a detail dialog with line items; biller can **mark as paid / cleared**; billed total is unchanged.
4. After clearance, billing queue and lab order both show **paid / cleared**; no stale pending state elsewhere.
5. Realtime or refresh keeps billing and lab views in sync.
6. Existing billing and lab tests pass; add tests for submit → billing visibility → global clearance if gaps exist.

