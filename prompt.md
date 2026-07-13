# Prompt: Implement HOSSPI HMS Billing & Pricing Engine

## Role

You are implementing a **multi-tier billing and pricing engine** for HOSSPI HMS across database, backend, and Flutter. Extend existing Billing, Claims, Pharmacy, and Integrations modules — do not replace them or invent parallel billing paths.

## Goal

Ship an engine that:

1. Prices every billable item by **payment mode** (self-pay) and by **insurance payer/plan**.
2. Resolves the correct price + co-pay / insurer share at charge time from **patient payer context**.
3. Treats **pharmacy** and **facility** as separate commercial entities (price, invoice, closeout).
4. Powers **every billing UI** (request/order/charge modals), not only the Billing workspace.
5. Adds an **insurer API connector layer** (eligibility → auth → claim → settlement) with manual fallback.

## Authority (read before coding)

1. [prompts/00-global-implementation-standards.md](./prompts/00-global-implementation-standards.md)
2. [prompts/09-billing-module-prompt.md](./prompts/09-billing-module-prompt.md)
3. [prompts/10-claims-module-prompt.md](./prompts/10-claims-module-prompt.md)
4. [prompts/18-pharmacy-module-prompt.md](./prompts/18-pharmacy-module-prompt.md)
5. [prompts/31-integrations-module-prompt.md](./prompts/31-integrations-module-prompt.md)
6. [`.cursor/app-write-up.mdc`](./.cursor/app-write-up.mdc) and relevant [`.cursor/flows/`](./.cursor/flows/)

## Non-negotiable rules

| # | Rule |
| - | ---- |
| 1 | One shared price resolver on the backend; one shared billing panel on the frontend. No module-private price logic. |
| 2 | Extend `ClinicalRequestBillingPanel` / `clinical_request_billing_state.dart` — do not fork per module. |
| 3 | Extend `clinical-request-billing.js` and Claims services — do not add a second charge pipeline. |
| 4 | Billing owns invoices/balances; Claims owns insurer workflow; this engine feeds both. |
| 5 | Persist resolved price, price-book ref, payment mode, payer/plan, co-pay, insurer share, and billing entity on each charge line. |
| 6 | Instant UI sync after mutations (`frontend/.cursor/instant_ui_sync.mdc`). |
| 7 | Localized hospital language only (`app_en.arb`); no UUIDs/enums in UI copy. |
| 8 | RBAC + ABAC + tenant/facility scope on all new APIs and screens. |

## Current baseline (do not regress)

| Exists today | Gap to close |
| ------------ | ------------ |
| Single `unit_price` on catalogs + facility offerings | Multi-tier price book (self-pay × insurer/plan) |
| Drug dual price: pharmacy vs facility + `price_source` | Entity-aware invoices and closeouts |
| Invoices, payments, clinical pay-now / bill-later | Engine-driven amounts + co-pay split in all dialogs |
| Manual coverage plans / pre-auth / claims | Patient enrollment + eligibility + payer adapters |
| Generic `integration` config | Insurer adapter interface (stub first) |

**Anchor files:** `backend/prisma/schema.prisma`, `backend/src/lib/billing/clinical-request-billing.js`, `backend/src/lib/billing/financials.js`, `frontend/lib/shared/clinical_actions/clinical_request_billing_panel.dart`, `frontend/lib/shared/clinical_actions/clinical_request_billing_state.dart`, Billing / Claims / Pharmacy feature modules.

---

## Required behavior

### A. Price book

For each billable item (drug, lab, radiology, consultation, procedure/service), support tariffs for:

- Self-pay / cash
- Each insurance company (optionally per coverage plan)

**Resolve at charge time (highest wins):**

1. item + facility + payment mode + coverage plan  
2. item + facility + payment mode + insurer  
3. item + facility + payment mode (self-pay)  
4. existing facility offering / tenant catalog fallback  

Require `effective_from` / `effective_to`. Existing `unit_price` becomes the self-pay default fallback after migration.

### B. Patient payer context

On insurance ID capture (manual / RFID):

1. Resolve **enrollment** (member ID, plan, validity, co-pay rules).  
2. Verify eligibility (manual first; API when configured).  
3. Attach payer context to the encounter so all charges use the correct tier and split.  

Extend OPD coverage verification — do not build a parallel flow.

### C. Pharmacy vs facility

| Context | Price | Billing entity |
| ------- | ----- | -------------- |
| Pharmacy-originated sale/dispense | `PHARMACY` | Pharmacy |
| OPD / IPD / theatre / ward / other departments | `FACILITY` | Facility |

Pharmacy may choose pharmacy vs facility price only for pharmacy-originated sales. Facility-originated charges always use facility tariffs. Same visit may produce separate invoices/closeouts per entity.

### D. Charge pipeline

On every chargeable action:

1. Load payer context  
2. Resolve unit price (price book + entity)  
3. Compute insurer share + patient co-pay / uncovered balance  
4. Gate on pre-auth when required  
5. Write invoice lines with audit metadata  
6. Preserve pay-now vs bill-later  

`coverage_percentage` and co-pay fields must drive math, not display only.

### E. All billing UIs must use the engine

Upgrade the shared panel once, then wire every consumer. **No orphan billing UIs.**

| Surface | Update these entry points |
| ------- | ------------------------- |
| Lab | `clinical_lab_order_action_dialog.dart`, `clinical_lab_request_catalog_dialog.dart` |
| Radiology | `clinical_radiology_order_action_dialog.dart`, `clinical_radiology_request_catalog_dialog.dart` |
| Pharmacy / Rx | `clinical_prescription_action_dialog.dart`, pharmacy billing helpers / dispense billing |
| Theatre | `theater_schedule_case_form.dart` + procedure charge dialogs |
| OPD | `opd_encounter_dialog.dart`, consultation payment / coverage panels |
| IPD / Nursing | Clinical-action order dialogs launched from those workspaces |
| Patients | Enrollment / charge dialogs on `patient_registry_page.dart` |
| Dental / physiotherapy / other billable modules | Same shared panel wherever charges exist or are planned |
| Billing cashier | Receive-payment / add-charge dialogs — show resolved amounts, co-pay, insurer share |

Each dialog must: show engine-resolved line prices for the patient payer; show co-pay / insurer share when insured; keep pay-now / bill-later; submit the engine payload (price-book ref, payment mode, payer/plan, shares, billing entity); refresh instantly when payer or items change; never hard-code amounts.

### F. Insurer connectors

Visit automation target: capture ID → eligibility → care/charges → auth if needed → claim submit → patient pays balance → track claim → settlement updates accounting.

- One adapter interface: `eligibility`, `authorize`, `submitClaim`, `getClaimStatus`, `parseWebhook`
- Credentials per facility × insurer, encrypted server-side only
- Ship interface + stub/mock first; real payer adapters later
- Manual Claims workspace must work when no API is configured

---

## Execute in this order

### Step 1 — Schema & migrations

Add (names may match existing Prisma style):

- [ ] Price-book / tariff rows linked to catalog entities + `payment_mode`, optional insurer/plan, `unit_price`, currency, effective dates, tenant/facility scope  
- [ ] Patient insurance enrollment  
- [ ] Billing entity on invoices / payments / closeouts (`FACILITY` \| `PHARMACY`)  
- [ ] Line fields: resolved price source, shares, co-pay, price-book ref  
- [ ] Insurer integration config (adapter type + credentials)  
- [ ] Migrate existing `unit_price` → self-pay fallback  

Prefer one price-book model (typed/polymorphic FK consistent with schema) over `unit_price_insurance_x` columns.

### Step 2 — Backend engine

- [ ] Central price resolver  
- [ ] Co-pay / coverage split helper  
- [ ] Hook resolver into `clinical-request-billing.js` and cashier add-charge paths  
- [ ] CRUD APIs for price books + enrollments (correct permissions)  
- [ ] Entity-aware invoice creation + shift/day close aggregation  
- [ ] Targeted backend tests for resolution matrix, co-pay math, entity split  

### Step 3 — Shared Flutter billing surface

- [ ] Upgrade `ClinicalRequestBillingPanel` + `clinical_request_billing_state.dart` for price-book resolution, payer context, co-pay/insurer share, billing entity  
- [ ] Admin/catalog UI to maintain self-pay + per-insurer prices  
- [ ] Extend OPD coverage / enrollment UX  
- [ ] Audit and update **every** dialog in §E to use the shared panel  
- [ ] Billing workspace: display payer, co-pay, insurer share, billing entity; support split payments  
- [ ] Instant UI updates; all strings in `app_en.arb`  

### Step 4 — Insurer adapter layer

- [ ] Adapter interface + stub/mock  
- [ ] Wire Claims submit/reconcile through adapter when configured  
- [ ] Webhook/poll status → invoice settlement updates  
- [ ] Super-admin settings for API URL, keys, enable/disable  

### Step 5 — Verify & document

- [ ] Flutter: format, analyze, tests for panel + key dialogs  
- [ ] Backend: targeted module tests  
- [ ] Smoke: lab, radiology, pharmacy, theatre, OPD consultation — insured and self-pay  
- [ ] Cross-link from prompts 09 / 10 / 18 when behavior lands  

---

## Out of scope

- Implementing every real insurer production API in v1 (interface + stub only)
- Replacing Billing or Claims workspaces
- Changing clinical order ownership (orders stay in their modules; engine only prices/splits)

## Definition of done

- [ ] Distinct self-pay and per-insurer/plan prices configurable per billable item  
- [ ] Charge-time auto-resolution from patient payer context (override only with permission + audit)  
- [ ] All billing modals listed in §E use the shared engine panel — no private/hard-coded price paths  
- [ ] Co-pay and insurer share visible in request dialogs and on invoices  
- [ ] Pharmacy vs facility prices, invoices, and closeouts work as separate entities  
- [ ] Claims amounts match insurer share from the same priced lines  
- [ ] Adapter path works when configured; manual Claims path works when not  
- [ ] Historical lines keep original resolved prices/shares  
- [ ] Schema, APIs, DTOs, and Flutter models aligned; quality gates pass  

## Constraints for the implementer

- Prefer smallest change that lands the engine end-to-end; avoid drive-by refactors.  
- Match existing code style, naming, and module boundaries.  
- Do not commit unless explicitly asked.  
- If a product decision is blocked (e.g. price-book shape), choose the option that preserves auditability and existing fallbacks, document it briefly, and continue.
