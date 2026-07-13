# Prompt: Implement HOSSPI HMS Billing, Pricing & Insurance Engine

## Role

You are implementing a **multi-tier billing and pricing engine** plus a **comprehensive Insurance & Claims module** for HOSSPI HMS across database, backend, and Flutter. Extend existing Billing, Claims, Pharmacy, and Integrations modules — do not replace them or invent parallel billing/claims paths.

## Goal

Ship an engine and claims stack that:

1. Models **insurance companies** with **multiple schemes**, each scheme having its own **offers** (covered services, tariffs, co-pay, limits, exclusions).
2. Prices every billable item by **payment mode** (self-pay) and by **insurer + scheme** (not a single flat insurer price).
3. Resolves the correct price + co-pay / insurer share at charge time from **patient payer context** (company + scheme + enrollment).
4. Treats **pharmacy** and **facility** as separate commercial entities (price, invoice, closeout).
5. Powers **every billing UI** (request/order/charge modals), not only the Billing workspace.
6. Delivers a **complete Insurance & Claims workspace**: enrollment, eligibility, scheme offers, pre-auth, claim prep/submit/track, partial/reject/resubmit, settlement — with insurer API automation and manual fallback.

## Authority (read before coding)

1. [prompts/00-global-implementation-standards.md](./prompts/00-global-implementation-standards.md)
2. [prompts/09-billing-module-prompt.md](./prompts/09-billing-module-prompt.md)
3. [prompts/10-claims-module-prompt.md](./prompts/10-claims-module-prompt.md) — extend; do not weaken
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
| 5 | Persist resolved price, price-book ref, payment mode, **insurer + scheme**, co-pay, insurer share, and billing entity on each charge line. |
| 6 | An insurance company may have **many schemes**; each scheme may have **different offers** (tariffs, coverage %, co-pay, covered catalog items, limits, exclusions). Never collapse company → one price. |
| 7 | Patient enrollment binds to a **specific scheme** (not only the company). Price resolution and claims use that scheme’s offers. |
| 8 | Instant UI sync after mutations (`frontend/.cursor/instant_ui_sync.mdc`). |
| 9 | Localized hospital language only (`app_en.arb`); no UUIDs/enums in UI copy. |
| 10 | RBAC + ABAC + tenant/facility scope on all new APIs and screens. |

## Domain model (product language)

Use hospital language in UI; map cleanly in schema:

| Concept | Meaning | Suggested persistence |
| ------- | ------- | --------------------- |
| **Insurance company** | Payer organization (e.g. Jubilee, AAR, NHIS) | Dedicated `insurance_company` (or evolve `coverage_plan.provider_name` into a real company entity) |
| **Scheme** | Product/plan under that company (e.g. Gold, Silver, Corporate Outpatient) | `coverage_plan` **or** new `insurance_scheme` linked to company — one company → many schemes |
| **Offer** | What a scheme covers and at what terms for a service/product | Scheme-linked **price-book rows** + optional **benefit/offer rows** (covered item, limits, co-pay override, requires-auth flag) |
| **Enrollment** | Patient membership on a scheme (member ID, validity, primary flag) | `patient_insurance_enrollment` → scheme (+ company via scheme) |
| **Payer context** | Active company + scheme + enrollment on the encounter | Attached at registration / coverage verify |

**Example:** Company *AAR* has schemes *AAR Gold* and *AAR Silver*. CBC may be UGX 25,000 on Gold and UGX 30,000 on Silver; Gold may cover 90% with 10% co-pay while Silver covers 70% with fixed co-pay. Price book and claims must distinguish these.

## Current baseline (do not regress)

| Exists today | Gap to close |
| ------------ | ------------ |
| Single `unit_price` on catalogs + facility offerings | Multi-tier price book (self-pay × company × **scheme**) |
| `coverage_plan` with flat `provider_name` + `%` | Explicit **company → schemes → offers** hierarchy |
| Drug dual price: pharmacy vs facility + `price_source` | Entity-aware invoices and closeouts |
| Invoices, payments, clinical pay-now / bill-later | Engine-driven amounts + co-pay split in all dialogs |
| Manual coverage plans / pre-auth / claims | Enrollment on **scheme**, eligibility, offer-aware claims |
| Generic `integration` + stub adapter | Payer connectors scoped to company (optionally scheme) |
| Claims workspace scaffold | Comprehensive claims desk (queues, pre-auth, submit, settle, partial/reject) |

**Anchor files:** `backend/prisma/schema.prisma`, `backend/src/lib/billing/clinical-request-billing.js`, `backend/src/lib/billing/price-resolver.js`, `backend/src/lib/billing/coverage-split.js`, `backend/src/lib/insurer/adapter.js`, `frontend/lib/shared/clinical_actions/clinical_request_billing_panel.dart`, `frontend/lib/features/claims/`, Billing / Pharmacy modules.

---

## Required behavior

### A. Insurance companies, schemes, and offers

**Admin must configure:**

1. **Insurance company** — name, code, contact, active flag, optional default API integration.
2. **Schemes under that company** — name, code, effective dates, default coverage %, default co-pay type/value, status (active/retired).
3. **Offers per scheme** — for each billable catalog item (or category):
   - negotiated tariff (or inherit scheme default / facility self-pay)
   - coverage % override (optional)
   - co-pay override (optional)
   - annual/visit/item limits (optional)
   - requires pre-authorization (bool)
   - excluded (bool)
   - effective dating

**Rules:**

- One company → many schemes; schemes do not cross companies.
- Offers are scheme-scoped; two schemes under the same company may differ on every dimension.
- Company-level tariff (no scheme) is only a **fallback**, never a substitute when the patient is enrolled on a scheme.
- Migrate existing `coverage_plan` rows into this hierarchy without losing claims/pre-auth links (prefer evolving `coverage_plan` into scheme + adding `insurance_company`, or map 1:1 with clear migration notes).

### B. Price book (aligned to schemes)

For each billable item, support tariffs for:

- Self-pay / cash
- Insurance company (fallback only)
- **Insurance company + scheme** (preferred for insured patients)

**Resolve at charge time (highest wins):**

1. item + facility + payment mode + **scheme** (+ offer overrides)  
2. item + facility + payment mode + insurance company  
3. item + facility + payment mode (self-pay)  
4. existing facility offering / tenant catalog fallback  

Require `effective_from` / `effective_to`. Existing `unit_price` remains self-pay default fallback.

### C. Patient payer context & eligibility

On insurance ID capture (manual / RFID):

1. Resolve **enrollment** → member ID, **company**, **scheme**, validity, co-pay rules.  
2. Verify eligibility (manual first; API when configured) against that scheme.  
3. Load scheme **offers** relevant to the visit (covered services, auth flags, limits).  
4. Attach payer context (`companyId`, `schemeId`, enrollment, coverage %, co-pay) to the encounter.  

Extend OPD coverage verification — staff selects/confirm **company + scheme** (or auto-resolve from member ID), not a free-floating plan list that ignores company hierarchy.

### D. Pharmacy vs facility

| Context | Price | Billing entity |
| ------- | ----- | -------------- |
| Pharmacy-originated sale/dispense | `PHARMACY` | Pharmacy |
| OPD / IPD / theatre / ward / other departments | `FACILITY` | Facility |

Pharmacy may choose pharmacy vs facility price only for pharmacy-originated sales. Facility-originated charges always use facility tariffs. Same visit may produce separate invoices/closeouts per entity.

### E. Charge pipeline

On every chargeable action:

1. Load payer context (self-pay **or** company + **scheme**)  
2. Resolve unit price via price book / scheme offer + entity  
3. Apply offer rules: exclusions → patient 100%; covered → coverage % + co-pay; auth-required → gate  
4. Compute insurer share + patient balance  
5. Write invoice lines with audit metadata (company, scheme, offer/price-book ref, shares)  
6. Preserve pay-now vs bill-later  

Coverage % and co-pay (scheme defaults **or** offer overrides) must drive math, not display only.

### F. All billing UIs must use the engine

Upgrade the shared panel once, then wire every consumer. **No orphan billing UIs.**

| Surface | Update these entry points |
| ------- | ------------------------- |
| Lab | `clinical_lab_order_action_dialog.dart`, `clinical_lab_request_catalog_dialog.dart` |
| Radiology | `clinical_radiology_order_action_dialog.dart`, `clinical_radiology_request_catalog_dialog.dart` |
| Pharmacy / Rx | `clinical_prescription_action_dialog.dart`, pharmacy billing helpers / dispense billing |
| Theatre | `theater_schedule_case_form.dart` + procedure charge dialogs |
| OPD | `opd_encounter_dialog.dart`, consultation payment / coverage panels |
| IPD / Nursing | Clinical-action order dialogs launched from those workspaces |
| Patients | Enrollment (company + scheme) / charge dialogs on `patient_registry_page.dart` |
| Dental / physiotherapy / other billable modules | Same shared panel wherever charges exist or are planned |
| Billing cashier | Receive-payment / add-charge — show company, scheme, co-pay, insurer share |

Each dialog must: show engine-resolved line prices for the patient’s **scheme**; show co-pay / insurer share when insured; keep pay-now / bill-later; submit engine payload (price-book/offer ref, payment mode, company, scheme, shares, billing entity); refresh instantly when payer or items change; never hard-code amounts.

### G. Comprehensive Insurance & Claims module

Claims owns the insurer workflow end-to-end. Make it **workspace-complete**, not CRUD-only.

#### G1. Catalog & configuration (Claims / Admin)

- Manage insurance companies and their schemes (modal-first).  
- Per-scheme offers editor (search catalog items; set tariff, coverage, co-pay, auth, exclusion, limits).  
- Link insurer API credentials to company (optional scheme override).  
- RBAC: claims/admin write for config; clinical/billing read for lookup.

#### G2. Enrollment & eligibility

- Create/update patient enrollments (company, scheme, member ID, validity, primary).  
- Verify eligibility (manual checkbox path + API when enabled).  
- Surface active enrollment on patient, OPD, IPD, and Claims detail.  
- Handle expired / suspended / rejected eligibility with clear hospital language.

#### G3. Pre-authorization

- Create pre-auth for admission, procedure, package, or high-cost order — tied to **scheme + encounter/admission**.  
- Statuses: pending, approved, partial, denied, expired, cancelled.  
- Track approved vs consumed amounts; warn/block orders when insufficient (per IPD/OPD flow gates).  
- Record insurer auth reference; resubmit when denied.

#### G4. Claim lifecycle

- Build claim from invoice/encounter lines that belong to the patient’s scheme (amounts = insurer share from engine).  
- Submit (adapter when configured; else manual mark submitted).  
- Record insurer response: approved, **partial**, rejected, paid.  
- Resubmit after rejection with notes/documents.  
- Reconcile settlement amounts → update invoice balances / accounting hooks.  
- Track payer reference, submitted_at, resubmitted_at, settlement_amount.

#### G5. Claims workspace UX

- Queues: eligibility pending, pre-auth pending, claims to submit, awaiting insurer, partial, rejected, ready to settle, settled.  
- Detail panel: patient, company, scheme, enrollment, linked invoices, line shares, auth status, claim timeline.  
- Actions via in-page dialogs only (create auth, submit claim, record response, resubmit, settle).  
- Realtime badges/queues; instant UI after mutations.  
- Integrate with Billing `CLAIMS_PENDING` without duplicating cashier payment capture.

#### G6. Visit automation (when API configured)

1. Capture insurance ID → resolve company + scheme enrollment  
2. Eligibility check  
3. Care / charges (engine uses scheme offers)  
4. Pre-auth if offer requires it  
5. Claim prep + submit  
6. Patient pays co-pay / balance; receipt  
7. Claim status sync (poll/webhook)  
8. Settlement updates accounting  

Manual Claims desk remains fully usable when no API is configured.

#### G7. Insurer connectors

- Adapter interface: `eligibility`, `authorize`, `submitClaim`, `getClaimStatus`, `parseWebhook`  
- Credentials per facility × **company** (optional scheme override), encrypted server-side  
- Stub/mock first; real adapters later  
- Never expose secrets to Flutter clients  

---

## Execute in this order

### Step 1 — Schema & migrations

- [x] `insurance_company` (or equivalent) + **schemes** under company (evolve/migrate `coverage_plan`)  
- [x] Scheme **offers** / benefit rows (catalog item or category + tariff/coverage/co-pay/auth/exclusion/limits + effective dates)  
- [x] Price-book rows keyed by payment mode + optional company + **scheme** + billing entity  
- [x] Patient enrollment → **scheme** (and company via scheme)  
- [x] Billing entity on invoices / payments / closeouts  
- [x] Line fields: company, scheme, offer/price-book ref, shares, co-pay  
- [x] Insurer integration config scoped to company (optional scheme)  
- [x] Migrate existing `unit_price` / `coverage_plan` without breaking live claims  

### Step 2 — Backend pricing + claims engine

- [x] Price resolver respects scheme → company → self-pay order  
- [x] Coverage-split uses scheme defaults and offer overrides  
- [x] Hook into `clinical-request-billing.js` and cashier paths  
- [x] CRUD: companies, schemes, offers, price books, enrollments  
- [x] Enrollment verify + eligibility via adapter  
- [x] Pre-auth + claim services use scheme/offer context; claim amounts = insurer share  
- [x] Claims-workspace aggregator API (queues + lookups)  
- [x] Entity-aware invoice/closeout aggregation  
- [x] Targeted tests: scheme matrix, offer overrides, co-pay, claim/adapter paths  

### Step 3 — Flutter Claims + billing surfaces

- [x] Claims workspace: company/scheme/offers admin, enrollment, pre-auth, claim lifecycle (§G)  
- [x] Upgrade shared billing panel for company + scheme + shares  
- [ ] Admin/catalog: maintain self-pay and **per-scheme** tariffs/offers  
- [x] OPD coverage: company + scheme selection / auto-resolve from member ID  
- [ ] Wire every dialog in §F  
- [x] Billing workspace: show company, scheme, co-pay, insurer share, billing entity  
- [x] Instant UI; all strings in `app_en.arb`  

### Step 4 — Insurer adapter layer

- [x] Adapter interface + stub/mock  
- [x] Wire eligibility / auth / claim submit / status into Claims services  
- [ ] Webhook/poll → settlement updates  
- [ ] Super-admin settings for company API URL, keys, enable/disable  

### Step 5 — Verify & document

- [x] Flutter format / analyze / tests (panel + claims flows)  
- [x] Backend targeted module tests  
- [ ] Smoke: two schemes under one company with different CBC prices and co-pays; lab/radiology/pharmacy/OPD  
- [ ] Smoke: pre-auth → claim → partial → resubmit → settle  
- [x] Cross-link prompts 09 / 10 / 18  

---

## Out of scope

- Implementing every real insurer production API in v1 (interface + stub only)  
- Replacing Billing or Claims shell routes — extend workspaces  
- Changing clinical order ownership (orders stay in their modules; engine only prices/splits)  

## Definition of done

- [x] Insurance companies support **multiple schemes**, each with **distinct offers**  
- [x] Distinct self-pay and per-scheme prices configurable per billable item  
- [x] Enrolled patient resolves to company + scheme; charge-time prices/co-pays follow that scheme’s offers  
- [ ] All billing modals in §F use the shared engine panel — no private/hard-coded price paths  
- [x] Co-pay and insurer share visible in request dialogs and on invoices (with company + scheme labels)  
- [x] Pharmacy vs facility prices, invoices, and closeouts work as separate entities  
- [x] Claims workspace covers enrollment, eligibility, pre-auth, submit, partial/reject/resubmit, settlement  
- [x] Claim amounts match insurer share from the same scheme-priced lines  
- [x] Adapter path works when configured; manual Claims path works when not  
- [x] Historical lines keep original resolved prices/shares/scheme refs  
- [x] Schema, APIs, DTOs, and Flutter models aligned; quality gates pass  

## Constraints for the implementer

- Prefer smallest change that lands company → scheme → offer end-to-end; avoid drive-by refactors.  
- Prefer evolving `coverage_plan` into **scheme** under `insurance_company` over abandoning existing claim FKs.  
- Match existing code style, naming, and module boundaries.  
- Do not commit unless explicitly asked.  
- If a product decision is blocked (e.g. offer table vs price-book-only), choose the option that preserves per-scheme auditability and existing fallbacks, document it briefly, and continue.
