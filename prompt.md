# Billing & Pricing Engine — Implementation Prompt

## Objective

Design and implement a **multi-tier billing and pricing engine** for HOSSPI HMS so facilities can charge differently by **payment mode** (self-pay / cash) and by **insurance payer**, resolve the correct price at bill time from patient coverage, treat **pharmacy and facility as separate commercial entities** where needed, and integrate insurers via API for eligibility, authorization, claims, and settlement.

This prompt extends — it does not replace — the existing Billing and Claims modules:

1. [prompts/09-billing-module-prompt.md](./prompts/09-billing-module-prompt.md) — cashier workspace, invoices, payments, closeouts
2. [prompts/10-claims-module-prompt.md](./prompts/10-claims-module-prompt.md) — coverage, pre-auth, claims lifecycle
3. [prompts/18-pharmacy-module-prompt.md](./prompts/18-pharmacy-module-prompt.md) — pharmacy dual price + dispense billing
4. [prompts/00-global-implementation-standards.md](./prompts/00-global-implementation-standards.md) — mandatory platform rules
5. [prompts/31-integrations-module-prompt.md](./prompts/31-integrations-module-prompt.md) — integration patterns

**Central rules:**

- Every billable item (medicines, lab tests, radiology, consultations, procedures, and other services) has a **price matrix**, not a single flat price.
- Price resolution is driven by **patient payer context** at the time of charge: self-pay vs insured, and which insurance company / plan.
- **Pharmacy** may sell at a pharmacy retail price; **facility departments** (OPD, IPD, theatre, etc.) sell at the facility price. Pharmacy and facility may invoice and close bills independently.
- Claims and Billing stay separated: Claims owns insurer workflow; Billing owns invoice balances and cashier actions. The pricing engine feeds both.

Deliver: schema + migrations, backend price resolver and billing hooks, admin/config UI, point-of-care billing UX, and an insurer connector layer ready for real payer APIs.

---

## Global Implementation Standards

Follow [prompts/00-global-implementation-standards.md](./prompts/00-global-implementation-standards.md) and the Global Implementation Standards tables in prompts 09 / 10 / 18.

| Area | Requirement |
| ---- | ----------- |
| Product scope | Respect Billing / Claims / Pharmacy / Integrations boundaries in [app-write-up.mdc](./.cursor/app-write-up.mdc). |
| Patient flows | Align with [`.cursor/flows/`](./.cursor/flows/) (especially OPD, IPD, pharmacy, discharge). |
| Architecture | UI/controllers → repository → API; RBAC + ABAC + tenant/facility scope + entitlements. |
| Database | Migrations for all schema changes; keep Prisma, APIs, DTOs, and Flutter models aligned. |
| Instant UI | Follow `frontend/.cursor/instant_ui_sync.mdc` for every shared mutation. |
| Quality gate | Frontend format / analyze / test; targeted backend tests for pricing, billing, and insurer adapters. |

---

## Current State (read before changing code)

### Already in place

| Area | Notes |
| ---- | ----- |
| Single-tier catalog prices | Lab / radiology / pharmacy / consultation have tenant + facility `unit_price` fields |
| Dual pharmacy vs facility drug price | `drug.unit_price` (pharmacy) + `facility_pharmacy_offering.unit_price` (facility); `price_source` `PHARMACY` \| `FACILITY` in clinical billing |
| Invoices / payments / adjustments | Full cashier stack under `/api/v1/billing` and Billing workspace |
| Coverage plans / pre-auth / claims | Manual CRUD + submit/reconcile status updates — **no external payer calls** |
| OPD coverage panel | Manual verify (staff selects plan); not enrollment- or API-backed |
| Generic integrations | `integration` + `config_json`; no insurer-specific adapter |
| Clinical request billing | `backend/src/lib/billing/clinical-request-billing.js` resolves lab/radiology/pharmacy prices today |

### Gaps this prompt closes

| Gap | Required outcome |
| --- | ---------------- |
| No price by insurer / payment mode | Price matrix per billable item × payment mode × payer/plan |
| `pricing_rule` not product-linked | Either evolve or replace with a real price book |
| No patient insurance enrollment | Membership, member ID, effective dates, plan link, co-pay rules |
| Co-pay / split billing not calculated | Patient vs insurer share on each charge and invoice |
| Pharmacy vs facility closeouts not split | Billing entity on invoices/payments/closeouts |
| Claims submit is DB-only | Payer connector: eligibility, auth, claim submit, status sync |
| No admin UI for multi-tier prices | Catalog / settings screens to maintain price books |

**Key files:**

- `backend/prisma/schema.prisma`
- `backend/src/lib/billing/clinical-request-billing.js`
- `backend/src/lib/billing/financials.js`
- `backend/src/modules/billing/`
- `backend/src/modules/coverage-plan/`
- `backend/src/modules/insurance-claim/`
- `backend/src/modules/facility-pharmacy-catalog/`
- `backend/src/modules/pharmacy-workspace/`
- `frontend/lib/features/billing/`
- `frontend/lib/features/claims/`
- `frontend/lib/features/pharmacy/`
- `frontend/lib/shared/clinical_actions/clinical_request_billing_panel.dart`
- `frontend/lib/shared/opd_actions/opd_coverage_verification_panel.dart`

---

## Product Behavior

### 1. Multi-tier pricing (price book)

When configuring any billable item (drug, lab test, radiology procedure, consultation, other service), the facility must be able to set:

| Dimension | Example |
| --------- | ------- |
| Self-pay / cash | Default walk-in / private patient price |
| Insurance company A (plan optional) | Negotiated tariff for that payer |
| Insurance company B | Different tariff |
| Other payers / plans as needed | Extendable matrix |

**Rules:**

- Cash patients and insured patients can have different prices for the same item.
- Different insurers can have different prices for the same item.
- Resolution order at bill time (propose; adjust only with product agreement):
  1. Exact match: item + facility + payment mode + coverage plan
  2. Item + facility + payment mode + insurer (company)
  3. Item + facility + payment mode (self-pay / cash)
  4. Existing facility offering / tenant catalog fallback
- Persist the **resolved unit price**, **price book key**, **payment mode**, and **payer/plan** on the charge / invoice line for audit.
- Effective dating (`effective_from` / `effective_to`) required so tariffs can change without rewriting history.

### 2. Patient payer context & eligibility

When a patient presents (card RFID / insurance ID / manual entry):

1. Capture or look up insurance member ID.
2. Resolve linked **patient enrollment** (plan, insurer, validity window).
3. Verify membership (manual first; API when configured):
   - subscription active / expired
   - covered services / exclusions
   - co-payment required (fixed, %, or none)
   - remaining benefits / limits when available
4. Attach verified payer context to the encounter / visit so all subsequent charges use the correct price tier and split.

OPD/IPD registration and payment gates must consume this context (extend existing OPD coverage panel; do not invent a parallel flow).

### 3. Pharmacy vs facility commercial entities

| Selling context | Price source | Invoicing / closeout |
| --------------- | ------------ | -------------------- |
| Pharmacy counter sale / pharmacy-billed dispense | Pharmacy price (`PHARMACY`) | Pharmacy billing entity |
| OPD, IPD, theatre, ward, other facility departments | Facility price (`FACILITY`) | Facility billing entity |

**Rules:**

- Keep and harden existing dual drug pricing (`drug.unit_price` vs `facility_pharmacy_offering`).
- Pharmacist chooses pharmacy vs facility price only when the sale is pharmacy-originated; facility-originated charges always use facility price.
- Pharmacy and facility may:
  - raise separate invoices for the same patient visit when lines belong to different entities
  - close / reconcile cash and claims separately (entity-aware shift/day close)
- Extend dual pricing to other inventory SKUs only if they are sold through pharmacy; do not invent prices on pure stock `inventory_item` without a catalog link.

### 4. Charge-time resolution (billing engine)

When items/services are added to a bill (consultation, lab, radiology, pharmacy, procedure, etc.):

1. Load patient payer context (self-pay or insured + plan).
2. Resolve unit price via price book + selling entity (`PHARMACY` / `FACILITY`).
3. Compute coverage split:
   - insurer share
   - patient co-pay / balance
   - uncovered lines → patient responsibility
4. If pre-authorization is required, request/check auth before finalizing covered lines.
5. Create/update invoice line(s) with amounts, shares, and audit metadata.
6. Keep pay-now vs bill-later behavior from clinical request billing.

`coverage_plan.coverage_percentage` (and any new co-pay fields) **must** participate in math — not display-only.

### 5. Insurance API integration (connector layer)

Facilities add an insurance company, then super-admins configure credentials (base URL, API key/secret, webhook secrets, environment) so HMS can automate the insurer flow.

**Target visit flow:**

1. Patient arrives → insurance ID captured (manual or RFID).
2. System verifies membership / eligibility (API when configured; manual fallback).
3. Care delivered; billable services added.
4. Coverage calculated; authorization requested if required.
5. Claim prepared from invoice/encounter lines and submitted.
6. Patient pays any balance / co-pay; receipt printed.
7. Claim status tracked (submitted → approved / partial / rejected / paid).
8. Settlement received → accounting / invoice balances update automatically.

**Design constraints:**

- One **payer adapter interface** (eligibility, authorize, submitClaim, getClaimStatus, parseWebhook) with pluggable insurer implementations.
- Store credentials per facility × insurer (or coverage plan), encrypted; never in Flutter clients.
- Manual Claims workspace remains fully usable when no API is configured.
- Reuse / extend `integration` + Claims module; do not build a second claims UI.

---

## Scope — Work Packages

Implement in this order unless blocked.

### WP1 — Data model

Add (names indicative; align with existing Prisma style):

- **Price book / tariff rows** linked to billable catalog entities (drug, lab test, radiology test, consultation fee source, generic service) with:
  - `payment_mode` (`SELF_PAY`, `INSURANCE`, …)
  - optional `insurer_id` / `coverage_plan_id`
  - `unit_price`, `currency`, effective dates, facility/tenant scope
- **Patient insurance enrollment** (member ID, plan, status, valid from/to, co-pay rules)
- **Billing entity** on invoices / payments / closeouts (`FACILITY` | `PHARMACY`)
- Line-level fields: resolved price source, payer shares, co-pay amount, price book reference
- Insurer integration config (credentials + adapter type) scoped to facility/tenant

Migrate carefully: existing single `unit_price` becomes the self-pay / default fallback.

### WP2 — Backend pricing & billing engine

- Central **price resolver** used by `clinical-request-billing.js` and any cashier add-charge paths.
- Co-pay / coverage split helper used when creating invoice lines and insurance claim amounts.
- APIs to CRUD price books and enrollments; authorize by admin / billing / pharmacy roles as appropriate.
- Entity-aware invoice creation and closeout aggregation.

### WP3 — Frontend configuration & point-of-care UX

- Admin / catalog UI to set self-pay + per-insurer prices when creating/editing billable items.
- Enrollment + eligibility UX (extend OPD coverage verification; Claims coverage lookup).
- Pharmacy billing: keep pharmacy vs facility price choice; show which entity owns the invoice.
- Billing workspace: show payer, co-pay, insurer share, billing entity; support split payments.
- Instant UI updates after price book and enrollment mutations.

### WP4 — Insurer connectors

- Adapter interface + at least one stub/mock adapter for local/dev.
- Wire eligibility → pre-auth → claim submit/status into Claims services (replace DB-only submit where adapter exists).
- Webhook / poll path for claim status; update invoice settlement and accounting hooks.
- Super-admin settings UI for API base URL, keys, and enable/disable automation.

### WP5 — Tests & docs

- Unit tests: price resolution matrix, co-pay math, entity split.
- API tests: enrollment, price book CRUD, claim adapter happy/fail paths.
- Flutter tests for pricing config widgets and coverage panel.
- Short note in module prompts 09 / 10 / 18 linking back to this engine when behavior lands.

---

## Acceptance Criteria

- [ ] Facility can configure distinct prices for the same item for self-pay and for each insurance company/plan.
- [ ] At billing time, the system picks the correct price from patient payer context without staff retyping amounts (override only with permission + audit).
- [ ] Insured visits resolve membership validity, covered services, and co-pay; patient balance and insurer share are visible on the invoice.
- [ ] Pharmacy can bill at pharmacy price; facility departments bill at facility price; invoices/closeouts can be separated by billing entity.
- [ ] Pre-auth and claims use the same priced lines; claim amounts match insurer share.
- [ ] With insurer API configured, eligibility / auth / claim submit / status update can run through the adapter; without it, manual Claims flow still works.
- [ ] Historical invoices retain the prices and shares originally charged (effective dating + line snapshots).
- [ ] Schema, backend, and Flutter stay aligned; quality gates pass for touched modules.

---

## Out of Scope (for this prompt)

- Building every real insurer’s production API in the first pass (ship interface + stub; add real adapters per payer as credentials become available).
- Replacing the Billing or Claims workspaces — extend them.
- Changing clinical order ownership (lab/radiology/pharmacy still own orders; pricing engine only resolves amounts).

---

## Implementation Notes

- Prefer extending `clinical-request-billing.js` and Claims services over parallel billing paths.
- Prefer one price-book table (polymorphic or typed FK pattern consistent with the schema) over scattering `unit_price_insurance_x` columns.
- Keep hospital language in UI (“Self-pay”, “Insurer share”, “Co-pay”) — never expose enum/UUID noise.
- All user-visible strings → `app_en.arb`.
)
