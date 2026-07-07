# Billing & Revenue — Invoices, Payments & Synchronization: Review, Fixes, and Web Test Coverage

## Context
The **Billing** module exposes an **All billing work items** queue (search by patient, ID, invoice, encounter, email, or phone; **Billing filters**; **Table settings**) and a per-invoice detail view opened by selecting a patient/invoice. Billing must be the single place where **every flow that requires payment or approval** is settled — including OPD consultations (e.g. the OPD **Pay consultation** flow: `Walk-in → Flow Started → Consultation Invoice Created → Payment due`), laboratory, radiology, pharmacy, and any other billable service. Review the module end to end and bring it to full, production-quality working order across frontend and backend. Every action must persist and reflect in the UI in **real time with no manual refresh**.

## Defects to fix
1. **Payment synchronization.** Payments are not well synchronized. When a payment is received/acknowledged, the **amount paid** and **remaining balance** must update immediately, and the invoice (and every screen consuming it — billing queue, OPD/encounter view, source module) must update accordingly in real time. Fix the `Remaining balance: Not available` display so it always shows a correct computed balance.
2. **Queue first-screen columns.** On the billing queue's first screen, each invoice must clearly display the **amount to be paid** and the **payment status** (paid / partially paid / not paid).
3. **Default filters.** **Billing filters** must default to showing **everything** (all invoices/work items), while remaining fully adjustable.
4. **Currency consistency.** Amounts must use the correct facility currency consistently (e.g. avoid mismatches like a consultation fee shown in USD when the facility bills in UGX).

## Functional requirements
All actions must be fully wired on **frontend and backend**, persist correctly, and reflect in the UI in **real time with no delay** across every screen that consumes billing data:

- **Billing queue:** Search, default-everything filters, and per-row display of amount due and payment status.
- **Receive payment:** Record a payment (amount, currency, payment method, optional transaction reference, optional notes). On success, amount paid and remaining balance update immediately, and the invoice status transitions correctly (unpaid → partially paid → paid). Support full and partial payments.
- **Issue refund:** Refund a payment; amounts, balance, and status update accordingly in real time.
- **Adjust:** Adjust an invoice/line item; recompute totals, balance, and status in real time.
- **Void:** Void an invoice; state and downstream screens reflect it immediately.
- **Approval flows:** Every flow requiring approval or payment is completed within billing and unblocks its source workflow (e.g. clearing OPD `Payment due` advances the encounter).
- **Real-time sync:** Any receive/refund/adjust/void reflects instantly across the billing queue, invoice detail, and originating module (OPD, lab, radiology, pharmacy) with no manual refresh.

*Note: the **Send** action is out of scope — do not implement or require it.*

## Access control
- The Billing module, queue, and all invoice actions (receive payment, refund, adjust, void) must be accessible to **billing/cashier staff, facility admins, tenant admins, and platform (super) admins**.
- Verify gating on both frontend (route/UI) and backend (authorization).

## Testing (web platform only)
- Add and/or update **unit, integration, E2E, and Patrol** tests using **Flutter's built-in testing tools** and **Patrol**, covering: queue search and per-row amount-due/status columns; default-everything billing filters; receive payment (full and partial, frontend + backend) with correct amount-paid/balance/status updates; refund, adjust, and void; payment-driven synchronization across billing queue, invoice detail, and source modules (e.g. OPD `Pay consultation` clearing `Payment due`); correct facility currency handling; and role-based access for all listed roles.
- Run the tests **exclusively on the web platform**.
- **Resolve every applicable test failure until all web tests pass.**

## Constraints
- Modify only application/test code required for the above; maximize code reuse.
- Keep the UI uniform and fully responsive on mobile, tablet, and desktop.
- Follow existing project conventions and applicable `.cursor` rules.
