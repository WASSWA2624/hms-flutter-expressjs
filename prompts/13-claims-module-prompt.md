# Insurance & Claims Module — Implementation Prompt

## Objective

Complete the **Insurance and Claims Module** for HOSSPI HMS so insurance desk staff and billers can manage coverage end-to-end: verify patient coverage, create and track **pre-authorizations**, prepare and **submit claims**, record insurer responses (approval, rejection, partial approval), manage resubmission, and reconcile settlements — integrated with Billing and patient care flows (OPD, IPD, discharge).

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Insurance and claims module boundaries vs Billing
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §4 insurance authorization, deposit gates, discharge financial closure
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — consultation payment gate and payer context on OPD encounters
4. [prompts/12-billing-module-prompt.md](./12-billing-module-prompt.md) — shared claims/pre-auth work items in billing workspace

**Central rule:** coverage, pre-auth, and claims attach to **patient + payer + invoice/encounter** context. Claims module owns insurer workflow state — Billing owns invoice balances and cashier actions. Do not duplicate invoice line capture in Claims.

Deliver an **audit-ready insurance workspace** (standalone or integrated with Billing): clear claim lifecycle, pre-auth tracking, and linkage to IPD authorization gates.

---

## Mandatory Reading (before any Claims change)

1. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Claims owns coverage, pre-auth, submission, tracking.
2. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §4 payment timing, insurance/credit paths, discharge settlement.
3. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — payer on worklist, payment gate.
4. Re-read [prompts/12-billing-module-prompt.md](./12-billing-module-prompt.md) — §3 insurance claims gaps in billing workspace.

---

## Flow Integration Requirements

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Claims module responsibility |
| ----------- | ---------------------------- |
| §4 Before admission | Pre-auth for elective admission / packages |
| §4 During stay | Track approved amount, exclusions, consumed amount |
| §4 At discharge | Insurance closure alongside final bill |
| §7 Waiting Payment / Authorization | Orders blocked until pre-auth or deposit — show auth status |
| §13 Insurance desk role | Submit pre-auth, track approvals, manage claim documents |
| §16 Encounter hub | Claims reference IPD encounter and linked invoices |

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Claims module responsibility |
| ----------- | ---------------------------- |
| Payer on worklist | Coverage verification before or at consultation payment gate |
| `WAITING_CONSULTATION_PAYMENT` | Insured patients may proceed on authorization vs cash |
| Insured outpatient visits | Claims for consultation and outpatient services post-visit |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Claims implementation |
| ------------ | --------------------- |
| Insurance and claims row | Coverage plans, pre-auth, claim prep, submission, tracking |
| Billing boundary | Invoices and payments in Billing — claims link to invoices |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend workspace | `frontend/lib/features/claims/` | `claims_workspace_page`, controller, repository |
| Backend APIs | `/api/v1/insurance-claims`, `/pre-authorizations`, `/coverage-plans` | CRUD, submit, reconcile — **no** `claims-workspace` aggregator |
| Billing workspace | `CLAIMS_PENDING` queue, claim work items | Overlaps — invoice-centric detail in billing |
| Billing repository gaps | Partial claim/pre-auth mutations | See [prompts/12-billing-module-prompt.md](./12-billing-module-prompt.md) §3 |
| IPD references | Insurance desk role in ipd-flow §13 | Authorization gates not fully wired in IPD UI |

### Known gaps to close

- **Workspace orchestration** — frontend merges pre-auth + claim APIs client-side; no backend `claims-workspace` module.
- **Pre-auth lifecycle UI** — create, submit, approve/deny, link to encounter/admission.
- **Claim submission and tracking** — submit, record insurer response, resubmit, settlement.
- **IPD authorization panel** — approved amount, pending, consumed on admission detail.
- **OPD insured visit flow** — coverage check at registration or payment gate.
- **Integration with Billing** — `CLAIMS_PENDING` queue with non-invoice detail layouts (billing prompt).
- **Tests and localization** — full coverage for claim/pre-auth flows.

---

## Scope — Core Capabilities

### 1. Coverage and plan lookup

- Verify patient coverage plan, member ID, effective dates, exclusions.
- Link coverage to encounters and invoices.

### 2. Pre-authorization

- Create pre-auth for admission, procedure, or package (IPD flow §4).
- Track status: requested, approved, denied, partial, expired.
- Block or warn on orders when authorization insufficient.

### 3. Claim preparation and submission

- Build claim from invoice/encounter line items.
- Submit to insurer; record reference numbers and documents.
- Track pending, approved, rejected, paid, resubmitted.

### 4. Settlement and reconciliation

- Record settlement amount; reconcile with invoice balance in Billing.
- Handle partial approvals and patient co-pay.

### 5. Work queues

- Pending submission, pending insurer response, denied/resubmit, unsettled.
- Integrate with Billing `CLAIMS_PENDING` or standalone queue.

---

## Module Boundaries (do not violate)

- Do not duplicate invoice creation — Billing owns invoice lifecycle.
- Do not mutate clinical orders or OPD/IPD stages from claims UI.
- Backend authorization mandatory for all claim/pre-auth mutations.

---

## Acceptance Criteria

- [ ] Pre-auth can be created and tracked for IPD admission and high-cost procedures.
- [ ] Claims can be submitted and status-updated with audit trail.
- [ ] IPD insurance gates show authorization state per ipd-flow §4.
- [ ] Billing workspace shows claim/pre-auth items with dedicated actions (or standalone module equivalent).
- [ ] OPD insured visits support coverage verification at payment gate.
- [ ] No raw UUIDs; permissions enforced; tests pass.

---

## Key File References

```
backend/src/modules/insurance-claim/
backend/src/modules/pre-authorization/
backend/src/modules/coverage-plan/
frontend/lib/features/billing/

Related prompts: prompts/12-billing-module-prompt.md, prompts/05-ipd-module-prompt.md, prompts/01-opd-module-prompt.md
```
