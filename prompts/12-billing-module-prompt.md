# Billing Module — Implementation Prompt

## Objective

Complete the **Billing Module** for Hosspi HMS so billing staff can manage the full revenue cycle: view pending charges and issued invoices, record payments, manage balances and clearance states, handle insurance claims and pre-authorizations, process refunds and adjustments, approve high-risk financial actions, and close shifts and days — with clear audit trails across all hospital departments.

Deliver a **professional, calm, cashier-grade workspace** that is easy to scan under pressure: clear hierarchy, minimal cognitive load, predictable primary actions, and no raw internal identifiers in the UI.

**Central payment rule:** clinical and departmental modules may collect payment at the point of care (pay now) or defer to the billing desk (bill later). The billing workspace must reflect both paths as a **single source of truth** for invoice and payment status — no duplicate charges, no ambiguous clearance.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Billing and cashier module boundaries
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §4 billing/deposit/insurance gates, §10 discharge financial clearance, §13 cashier role
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — `WAITING_CONSULTATION_PAYMENT`, payer on worklist, pay-consultation gate

---

## Flow Integration Requirements

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Billing module responsibility |
| ----------- | ----------------------------- |
| §4 Payment timing | Deposits before admission, interim bills during stay, pre-procedure auth, discharge settlement |
| §4 `Billing Deferred` | Emergency admits — show deferred flag; do not block urgent care in UI |
| §10 step 6 | Final bill, insurance claim, deposit adjustment before patient exit |
| §11 `Awaiting Billing Clearance` | Work items for discharge-linked invoices |
| §13 Cashier / Insurance desk | Collect deposit, payments, refunds; pre-auth and claims (with Claims module) |
| §16 Encounter hub | Invoices and payments link to IPD encounter — ledger per admission |

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Billing module responsibility |
| ----------- | ----------------------------- |
| `WAITING_CONSULTATION_PAYMENT` | Consultation invoice/payment via `pay-consultation` integration |
| Worklist billing state | Show payment relevance without replacing OPD stage ownership |
| Insured outpatient | Coverage and claims per [prompts/13-claims-module-prompt.md](./13-claims-module-prompt.md) |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Billing implementation |
| ------------ | ---------------------- |
| Billing row | Invoices, payments, receipts, refunds, adjustments, cashier, shift close |
| Clinical/department modules | Intake charges via orders — billing reflects status, does not re-enter orders |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/billing/` | `data/`, `domain/`, `presentation/` layers exist |
| Workspace UI | `billing_workspace_page.dart` | Summary cards, queue filters, work-item table, invoice detail (line items, payments, adjustments), payment/refund/adjustment/void/issue/send dialogs, shift/day close dialogs |
| Controller | `billing_workspace_controller.dart` | Realtime refresh, pagination, queue/search filters, invoice mutations, shift/day close |
| Repository | `billing_repository.dart` / `billing_repository_impl.dart` | Workspace overview, work items, issue/send invoice, receive payment, refund/adjustment/void requests, shift/day close |
| Backend workspace API | `backend/src/modules/billing/` | `/api/v1/billing/workspace`, `/work-items`, invoice/payment/adjustment mutations, `/approvals/:id/approve|reject`, `/patients/:id/ledger`, `/invoices/:id/document` |
| Billing libraries | `backend/src/lib/billing/` | `financials.js`, `identifiers.js`, `pdf.js`, `clinical-request-billing.js` |
| Clinical request billing | `clinical_request_billing_panel.dart`, `clinical_request_billing_state.dart` | Pay now vs bill later at lab/radiology/pharmacy order creation; shared payment methods and payload shape |
| OPD billing | `opd_billing_state.dart`, `opd_flow_actions_dialog.dart` | Consultation billing display and payment actions within OPD workflow |
| Standalone billing APIs | `/api/v1/invoices`, `/payments`, `/refunds`, `/billing-adjustments`, `/insurance-claims`, `/pre-authorizations`, `/coverage-plans`, `/pricing-rules` | CRUD and list endpoints available |
| Permissions | `AppPermissions.billingRead`, `billingWrite` | Route is permission-gated; approvers use admin roles |
| Feature flag | `billing_workspace_v1` | Backend and frontend require flag enabled (`FEATURE_BILLING_WORKSPACE_V1`) |
| Realtime | `RealtimeEventGroups.billingWorkspace` | Controller subscribes to billing domain events |
| Tests | `test/features/billing/` | DTO mapping and controller load/payment tests exist |

### Known gaps to close

- **Patient ledger** — `GET /billing/patients/:patientIdentifier/ledger` exists; not exposed in `BillingRepository` or UI (no per-patient financial history view from billing workspace or patient context).
- **Approval workflow UI** — backend supports approve/reject on `/billing/approvals/:id`; frontend repository and controller have no `approveApproval` / `rejectApproval`; approval queue items lack dedicated detail actions.
- **Insurance claims & pre-authorizations** — work items appear in `CLAIMS_PENDING` and timeline queues; detail panel is invoice-centric (`_BillingActionBar` only for invoices). No submit, track, approve, reject, or settle claim flows in the workspace.
- **Invoice document download** — `GET /billing/invoices/:id/document` exists; UI shows a stub snackbar (“Browser download is not available in this build yet”).
- **Admission deposits** — `_DepositPanel` is a static placeholder (“Admission deposit recording is unavailable…”).
- **Localization** — most billing copy lives in private `_BillingText` constants; not in `app_en.arb` (unlike other modules).
- **Encounter / discharge closeout** — no billing-workspace flow to review encounter charges, confirm clearance, and finalize financial close when all obligations are resolved.
- **Department charge context** — line items render description/qty/amount but do not surface source module, encounter, or service area (OPD, IPD, lab, etc.) when API provides it.
- **Non-invoice work items** — payments, refunds, claims, and approvals in the queue lack tailored detail layouts and action panels.
- **Tests** — limited widget/page coverage compared with lab/radiology/pharmacy clinical-action tests.

---

## Scope — Core Capabilities

Implement or finish the following, in priority order.

### 1. Cashier work queue and invoice lifecycle

**Goal:** Billers can triage work, open any queue item, and complete the standard invoice lifecycle end-to-end.

**Actions:**

- Keep the primary workspace focused on **queue → detail → action panel** (mirror Lab/Radiology `AppWorkspace` patterns).
- Preserve and polish existing queues: `NEEDS_ISSUE`, `PENDING_PAYMENT`, `CLAIMS_PENDING`, `APPROVAL_REQUIRED`, `OVERDUE`, plus **All work items**.
- Default queue to **Awaiting payment** (`PENDING_PAYMENT`) — highest daily cashier workload.
- Invoice actions (gate on `billingWrite` and entity capability flags):
  - **Issue** draft invoices
  - **Receive payment** (cash, card, mobile money, insurance, etc.)
  - **Send** invoice (email)
  - **Request adjustment** / **Request refund** / **Request void** (with approval when thresholds apply)
- Show financial summary on detail: effective total, paid, balance, clearance state chip.
- Use display IDs (`displayId`, `patientDisplayId`, `invoiceDisplayId`) — never surface raw UUIDs (see `backend_gap_cleanup_test.dart`).
- Preserve realtime sync via `RealtimeEventGroups.billingWorkspace`; avoid stale detail when the selected item updates.

**Reference APIs:** `GET /billing/workspace`, `GET /billing/work-items`, `POST /billing/invoices/:id/issue|send|void-request`, `POST /billing/payments/:id/reconcile`, `POST /billing/adjustments/request`.

### 2. Payment recording and balance management

**Goal:** Accurate payment capture, partial payments, and clear outstanding balance visibility.

**Actions:**

- Receive payment dialog: amount (default to balance due), method, reference, payer context — reuse patterns from `ClinicalRequestBillingPanel` / `opd_billing_state.dart` for method options and currency formatting.
- Reflect partial vs paid vs overdue states via `BillingClearanceState` and `billingStatus` chips — not redundant badges.
- Payment history section: method, amount, status, refundable indicator, transaction reference.
- After payment, refresh overview counts and re-select the affected invoice.
- Support insurance-method payments where backend marks `INSURANCE` — show insured clearance state without duplicating claim UI.

### 3. Insurance claims, pre-authorizations, and settlements

**Goal:** Billers can manage insurer workflows from pending submission through approval, rejection, and settlement.

**Actions:**

- Extend repository for claim and pre-auth mutations via existing `/api/v1/insurance-claims` and `/api/v1/pre-authorizations` where workspace APIs do not yet wrap them.
- When a work item `kind` is `claim`, `preAuthorization`, or `approval`, render a **dedicated detail layout** (not the invoice action bar):
  - Coverage plan, claim/pre-auth status, linked invoice and patient, submitted/approved/rejected dates, settlement amount when present.
  - Primary actions: submit claim, record insurer response, approve/reject (per permission), link to related invoice.
- Wire `CLAIMS_PENDING` queue to API-backed filters — already server-backed; ensure list columns and detail fields match backend serializer shapes (`mapClaim`, `CLAIM_INCLUDE`).
- Show claim/pre-auth items in timeline with distinct icons and statuses.
- Audit-friendly: surface who submitted and when when API provides actor metadata.

### 4. Approvals, adjustments, refunds, and voids

**Goal:** High-risk financial actions follow approval rules with clear cashier feedback.

**Actions:**

- Add `approveApproval` / `rejectApproval` to `BillingRepository` mapped to `/billing/approvals/:approvalIdentifier/approve|reject`.
- Approval queue detail: show request type (void, large adjustment, refund), requester, reason, linked invoice/payment, approve/reject actions (admin roles per backend `BILLING_APPROVER_SCOPES`).
- When `BillingMutationResult.approvalRequired` is true after submit, show non-blocking success with “Pending approval” state — do not imply immediate completion.
- Adjustment dialog: signed amount, reason, status; respect backend thresholds (`ADJUSTMENT_ABS_THRESHOLD`, percent threshold).
- Refund dialog: amount capped at refundable payment balance, reason, notes.

### 5. Patient ledger and cross-encounter billing view

**Goal:** Billers can review a patient’s full financial picture without leaving the module.

**Actions:**

- Add `getPatientLedger(patientIdentifier, query)` to repository; map to `GET /billing/patients/:patientIdentifier/ledger`.
- Entry points: patient context header action (“View ledger”), search-by-patient shortcut, optional deep-link from Patients module.
- Ledger view: chronological entries (invoices, payments, refunds, adjustments, claims), running balance summary, date-range filter.
- Keep ledger as a **secondary panel or route section** — do not replace the primary cashier queue.

### 6. Encounter closeout and discharge billing

**Goal:** When an encounter’s clinical care is complete, billers can confirm all charges are issued, paid or insured, and financially closed.

**Actions:**

- Surface encounter-linked invoices on detail when `encounter_id` is present on invoice/work item payloads.
- Add a **Close encounter billing** or **Finalize financial clearance** action when:
  - All linked invoices are issued and balance is zero, or insured/authorized per policy.
  - No pending approvals block closure.
- Coordinate with discharge and IPD modules — billing does not re-enter clinical data; it confirms financial readiness.
- Show discharge-billing queue items (invoices flagged overdue or tied to discharge encounters) prominently in **Overdue** / **Awaiting payment** filters.

### 7. Shift close, day close, and audit trail

**Goal:** End-of-shift reconciliation and traceable billing activity.

**Actions:**

- Keep shift close (expected vs actual amounts) and day close dialogs; ensure submit-for-approval checkbox maps to API `submit` field.
- Overview timeline: show recent invoices, payments, refunds, claims — already partially implemented; polish labels and empty states.
- Invoice document: wire `GET /billing/invoices/:id/document` to real download/preview (PDF) using existing `generateInvoicePdfBuffer` backend support.
- Remove or implement `_DepositPanel` — either wire admission deposit recording or remove the placeholder info panel to reduce noise.

### 8. Cross-module charge intake (all billable services)

**Goal:** Charges from every care area flow into billing without duplicate entry.

The module must support billing for all patient care areas and services, including:

| Area | Upstream intake | Billing desk role |
|------|-----------------|-------------------|
| OPD | `opd_flow_actions_dialog.dart`, consultation billing | Record visit payments; issue/consultation invoices |
| Emergency | Encounter + clinical orders | Pay now or bill later; cashier settlement |
| IPD / ICU | Encounter charges, bed fees, orders | Running account; discharge invoice |
| Discharge billing | Discharge workflow flags | Final settlement before release |
| Laboratory | `clinical_lab_order_action_dialog.dart` + `clinical-request-billing.js` | Bill later queue or reflect pay-now at order time |
| Radiology | `clinical_radiology_order_action_dialog.dart` | Same clinical billing pattern |
| Pharmacy | `clinical_prescription_action_dialog.dart` | Cashier or pharmacy counter payment paths |
| Physiotherapy, Theatre, Procedures | Clinical catalog / procedure terms | Invoice line items from catalog |
| Any other billable service | `/api/v1/invoices`, `/invoice-items`, `/pricing-rules` | Standard invoice lifecycle |

**Actions:**

- Do not duplicate order capture in billing — intake stays in clinical/department modules.
- Billing workspace displays line-item source context when available (module, order display ID, encounter).
- Reflect pay-now vs bill-later choices from `ClinicalRequestBillingPanel` on invoice/payment status.
- Optional: deep-link from clinical order rows or OPD billing actions to billing workspace with patient or invoice pre-selected.

---

## UI / UX Requirements

Follow `frontend/.cursor/ui-patterns.mdc`, `design-system.mdc`, `components.mdc`, and `layouts.mdc`. Mirror proven workspace patterns from **Lab**, **Radiology**, and **Pharmacy** (`AppWorkspace`, `AppListTable`, `AppWorkspaceDetailPanel`, `AppActionPanel`, `AppWorkspacePatientContextHeader`).

### Organization

- **Single primary task per screen region:** queue (left/list), detail (center/right), actions (grouped panel).
- **Progressive disclosure:** summary metric cards for at-a-glance workload; advanced search/filter collapsed; complex forms in dialogs only.
- **Four logical domains, clearly separated:**
  1. **Cashier queue** — triage and process invoices/payments (default landing).
  2. **Insurance & approvals** — claims, pre-auth, and approval-required items (distinct detail layouts).
  3. **Patient ledger** — per-patient financial history (secondary view).
  4. **Closeout** — shift close, day close, encounter financial finalize (toolbar actions + dialogs).
- Default landing: **Awaiting payment** queue with summary chips linking to other queues.
- Use consistent section titles, descriptions, and empty states (localized via `app_en.arb`).

### Simplicity

- **Reduce visual noise:** remove placeholder panels (deposits) unless implemented; avoid duplicate status badges (one clearance chip + one billing status field).
- **Limit table columns** to cashier essentials: patient, invoice/ref, status, amount, paid, balance, updated — hide optional columns via column visibility.
- **Action panel hierarchy:** primary action first (Receive payment when balance due → Issue when draft → Claim/approval actions for non-invoice items), destructive actions last (Void, Reject), disabled with tooltip when not allowed.
- **Payment UI:** compact financial summary on detail; full payment form only in dialog — do not repeat amount/method fields in the detail body.
- **One billing summary block** per invoice: total, adjustments, paid, balance — not scattered figures.
- **Forms:** one column on narrow viewports; inline validation; currency fields via `AppCurrencyAmountField`.
- **Loading/saving:** use `AppWorkspace` status tone and `AsyncStateScaffold` — no full-page reload for minor updates.

### Professional healthcare feel

- Accurate terminology: invoice, payment, claim, pre-authorization, adjustment, clearance — not generic “submit” or “item”.
- Calm visual hierarchy: neutral backgrounds, status color only on chips and critical balances.
- Audit-friendly: show who/when on payments, adjustments, and approvals when API provides it.
- Accessibility: semantic labels on search, tables, queue chips, and action buttons; keyboard-navigable dialogs.
- No raw UUIDs, internal enum codes, or debug field names in production UI.

---

## Architecture and Conventions

Follow `frontend/docs/workflows/feature-workflow.md` and `../.cursor/` rules.

| Rule | Requirement |
|------|-------------|
| Layering | UI/controllers → repository interface → repository impl → API client. No API calls from widgets. |
| State | Riverpod `AsyncNotifier` controllers; `Result<T>` / `AppFailure` for errors. |
| DTOs | `data/dtos/` with explicit mappers to `domain/entities/`. |
| Localization | Migrate `_BillingText` to `app_en.arb`; run codegen; no hard-coded user strings. |
| Permissions | `AccessGate` / `AppAccessActionGate` for write and approver actions. |
| Shared UI | Prefer `lib/shared/components`, `forms`, `layout`; reuse `ClinicalRequestBillingPanel` patterns for payment capture consistency. |
| File size | Extract widgets to `presentation/widgets/` when `billing_workspace_page.dart` grows; keep page compositional. |
| Tests | Mirror structure under `test/features/billing/`; cover controller transitions, DTO mapping, claim/approval dialogs, payment flows. |

**Do not** add feature business logic to `core/` or `shared/` unless genuinely cross-module (clinical billing panel already lives in `shared/clinical_actions/`).

**Reuse existing services** — analyze the codebase before adding endpoints, models, or UI. Extend `billing.service.js`, `clinical-request-billing.js`, and existing invoice/payment modules rather than duplicating financial logic.

---

## Suggested Implementation Order

1. **Localization + UI polish** — migrate `_BillingText` to `app_en.arb`; simplify detail layout; remove or implement deposit placeholder.
2. **Repository completion** — patient ledger, approve/reject approval, invoice document fetch.
3. **Non-invoice work items** — tailored detail layouts and actions for claims, pre-auth, approvals, refunds.
4. **Insurance workflows** — claim submission, status tracking, settlement recording.
5. **Patient ledger view** — secondary panel with summary and timeline.
6. **Encounter closeout** — clearance checks and finalize action when backend encounter billing hooks exist.
7. **Invoice document + deposits** — PDF download/preview; admission deposits if in scope.
8. **Cross-module deep links** — patient/invoice pre-selection from OPD, clinical orders, Patients module.
9. **Integration hardening** — realtime, queue alignment, pay-now vs bill-later smoke paths across lab/radiology/pharmacy/OPD.
10. **Tests + quality gate** — see below.

Work in small, reviewable increments. One clear responsibility per new file.

---

## Acceptance Criteria

- [ ] Biller can open Billing workspace, filter/search queues, open detail, and complete issue → receive payment flow.
- [ ] Partial payments, refunds, adjustments, and void requests work with API validation errors shown in UI.
- [ ] Approval-required mutations surface pending state; authorized approvers can approve/reject from the workspace.
- [ ] Claims and pre-authorizations appear in `CLAIMS_PENDING` queue with dedicated detail and status actions.
- [ ] Patient ledger is viewable per patient with invoice/payment/refund/claim history and balance summary.
- [ ] Payment status reflects both **cashier desk** and **point-of-care pay now** paths without duplicate charges.
- [ ] Charges from OPD, lab, radiology, pharmacy, and other modules appear as invoice line items with source context when available.
- [ ] Encounter-linked invoices show encounter context; financial closeout is available when balances and approvals are resolved.
- [ ] Invoice PDF/document download works (or graceful platform-specific preview).
- [ ] Shift close and day close post successfully with optional approval submission.
- [ ] All user-facing strings localized; permissions enforced; no raw internal IDs in production UI.
- [ ] UI organized into Cashier queue, Insurance/approvals, Patient ledger, and Closeout areas with calm, scannable layout.
- [ ] `flutter analyze` and `flutter test` pass; new tests cover repository mapping and primary workspace flows.

---

## Quality Gate

Before marking complete, run from `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Enable `FEATURE_BILLING_WORKSPACE_V1=true` (or default env) for backend integration tests. Add focused tests during development; run the full gate before PR or merge.

---

## Key File References

```
frontend/lib/features/billing/
├── data/dtos/billing_dtos.dart
├── data/repositories/billing_repository_impl.dart
├── domain/entities/billing_entities.dart
├── domain/repositories/billing_repository.dart
└── presentation/
    ├── controllers/billing_workspace_controller.dart
    └── pages/billing_workspace_page.dart

frontend/lib/shared/clinical_actions/
├── clinical_request_billing_panel.dart
├── clinical_request_billing_state.dart
└── dialogs/
    ├── clinical_lab_order_action_dialog.dart
    ├── clinical_radiology_order_action_dialog.dart
    └── clinical_prescription_action_dialog.dart

frontend/lib/shared/opd_actions/
├── opd_billing_state.dart
└── opd_flow_actions_dialog.dart

frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart  # billing-gate reference
frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart    # payment-status reference

backend/src/modules/billing/
├── routes/billing.routes.js
├── services/billing.service.js
├── repositories/billing.repository.js
└── schemas/billing.schema.js

backend/src/lib/billing/
├── clinical-request-billing.js
├── financials.js
├── identifiers.js
└── pdf.js

backend/src/modules/insurance-claim/
backend/src/modules/pre-authorization/
backend/src/modules/invoice/
backend/src/modules/payment/
backend/src/modules/coverage-plan/
backend/src/modules/pricing-rule/
```
