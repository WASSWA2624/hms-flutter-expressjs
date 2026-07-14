# Reception / Front-Desk Workspace — Implementation Prompt

## Objective

Create a role-focused Reception workspace over existing Patient Registry, OPD, IPD, Billing, Claims/Insurance, and Communications modules. Reception is **not** a separate entitlement module — it composes authorized actions from those modules for high-volume front-desk workflows.

**Source requirement:** [prompt.md](../prompt.md) §8  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md), [01-authorization-security.md](./01-authorization-security.md), [10-billing-engine-integration.md](./10-billing-engine-integration.md)

---

## Mandatory reading

1. [`.cursor/flows/opd-flow.mdc`](../.cursor/flows/opd-flow.mdc) — encounter start, reuse active encounter, routing
2. [`.cursor/app-write-up.mdc`](../.cursor/app-write-up.mdc) — Patient Registry, Billing, Communications boundaries
3. Triage boundary: triage capture stays in Triage module
4. Shared prompts 03–06 for UI building blocks

---

## Pre-implementation audit

- Identify existing reception/front-desk, patient registry, appointment, and check-in UIs.
- Compose a Reception workspace; do not fork parallel patient or billing engines.
- Ensure check-in / encounter-start / routing mutations are idempotent.

---

## Step-by-step instructions

### 1. Responsibilities (authorized composition)

Reception staff should be able to (when effectively permitted):

- Register patients; search existing; warn on likely duplicates before registration
- Edit patient information
- Schedule / reschedule / cancel appointments
- Check in patients; start encounters
- **Reuse an active encounter** when required by canonical OPD flow — never create parallel encounters
- Route patients; view queues and appointments
- Check requested services, estimated charges, outstanding balances; advise on payment methods
- Capture insurance information and payment method
- Capture cash / card / mobile money / other payments **only** through authorized Billing-owned cashier actions

### 2. Authorization hard split

Receptionists must **not**, unless granted specific effective Billing permission:

- Finalize, approve, adjust, waive, refund, reverse, reconcile, or close billing transactions

Rules:

- Clearly separate billing **guidance** from Billing-owned **operations**
- Hide unauthorized actions in UI
- Enforce the same restriction on the backend

### 3. UX design

- High-volume: minimize steps and in-screen navigation depth
- Keep standard responsive application shell
- Realtime queues, appointments, encounters, routing, waiting status
- Reuse shared components including step/progress (prompt 04)
- Fast search; keyboard-efficient desktop; touch-friendly mobile/tablet
- Duplicate-patient warnings; safe recovery from failed submissions
- Instant updates after successful registration, appointment, check-in, routing, queue, and payment persistence

### 4. Clinical boundary

- Triage capture remains in the Triage module
- Reception routes patients to canonical queues and does **not** duplicate clinical triage workflows

### 5. Backend / database

- Prefer composing existing Patient, OPD, Appointment, Billing, Claims, Communications APIs
- Idempotent check-in, encounter-start, and routing under retries; deterministic conflict handling
- Public IDs only; scoped lists; audit sensitive edits and payment handoffs
- No new “Reception” subscription module — use role permissions + existing module entitlements

### 6. Sync

- Patch acting-user views immediately on success
- Reconcile other authorized clients via scoped realtime events
- Online-only for payment capture and other financial finalization

---

## Tests

- Duplicate-patient warning path
- Active encounter reuse (no parallel encounters)
- Billing action hide/deny without Billing permission
- Idempotent check-in/start/routing under retry
- Mobile/tablet/desktop high-volume layouts
- Multi-client queue reconciliation

## Related prompts

00, 01, 03, 04, 05, 06, 10, 13
