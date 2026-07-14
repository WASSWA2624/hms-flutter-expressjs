# Billing Engine Integration — Implementation Prompt

## Objective

Fully integrate the centralized billing engine into every billable clinical/operational workflow so charges are atomic, idempotent, catalogue-driven, and never invented inside feature modules.

**Source requirement:** [prompt.md](../prompt.md) §6  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md)

---

## Mandatory reading

1. [`.cursor/app-write-up.mdc`](../.cursor/app-write-up.mdc) — Billing ownership
2. [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) — online-only financial finalization
3. [`backend/.cursor/`](../backend/.cursor/) billing/module standards as applicable
4. Clinical request billing UI patterns in `frontend/lib/shared/`
5. Access catalogs for Billing permissions

---

## Pre-implementation audit

- Locate centralized billing services vs feature-local charge creation.
- Map billing points in consultations, lab, radiology, procedures, pharmacy, admissions, theatre, nursing, consumables.
- Remove or redirect any independent billing logic in feature modules.

---

## Step-by-step instructions

### 1. Central engine ownership

- Generate charges **only** through the centralized billing engine at each owning workflow’s configured billing point.
- Feature modules must not create independent billing/charge writers.
- Always use effective-dated billing-catalogue prices, coverage rules, taxes, discounts, and facility/tenant context — **never hardcode financial values**.

### 2. Billable activities (auto-charge)

Wire catalogue-driven charges for:

- Consultations, Laboratory, Radiology, Procedures, Pharmacy  
- Admissions, Theatre, Nursing, Consumables  
- Future configurable services via catalogue — not new hardcoded paths  

### 3. Atomicity, traceability, idempotency

Each charge must be:

- Atomic with the triggering workflow step (or explicit compensating policy documented)
- Idempotent under retries and realtime reprocessing
- Traceable to originating encounter, order/service, actor, and catalog item

Explicit uniqueness rules:

- Never bill a consultation twice for one encounter
- Prevent duplicate service charges unless catalog + authorized workflow explicitly allow a repeat
- Retries and event reprocessing must not create additional charges

### 4. Database / migrations

- Ensure unique constraints / idempotency keys for billable events
- Effective-dated catalogue tables; preserve historical price snapshots on posted charges
- Migrate/remove obsolete feature-local charge tables after cutover
- Balanced ledger support for adjustments, waivers, reversals, refunds

### 5. Billing-owned financial workflows

Support through Billing module (not clinical UIs):

- Invoices, payments, receipts, refunds, adjustments, settlement  
- Cashier close, audit, reporting, reconciliation  

Rules:

- Payments, refunds, billing closeout, and other financial finalization = **online-only**
- Adjustments/waivers/reversals/refunds require explicit permissions, confirmation, reason where applicable, immutable audit, balanced ledger

### 6. Authorization & UI

- Display all and only in-scope billable items to authorized billing users
- Hide unauthorized financial actions (see Reception separation in prompt 12)
- Update clinical and billing views immediately after successful persistence
- Reconcile authorized clients without using realtime events to **initiate** charges

---

## Tests

- Idempotent charge creation under retry/reprocess
- Duplicate consultation prevention
- Catalogue price change does not alter posted charge snapshots
- Online-only enforcement for payments/refunds/closeout
- Unauthorized financial action denial
- Instant UI + second-client reconciliation after charge post

## Related prompts

00, 08, 09, 12, 13
