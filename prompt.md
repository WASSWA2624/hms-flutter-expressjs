# Pharmacy Module — Implementation Prompt

## Objective

Complete the **Pharmacy Module** for Hosspi HMS so pharmacists can manage medication inventory, maintain drugs and formulary entries, receive orders from clinical workflows, collect or confirm payment when appropriate, and execute the full dispense lifecycle with accuracy, traceability, and clear cross-module handoffs.

**Payment rule:** medication charges may be settled at the **cashier/billing desk** or **directly at the pharmacy** — both paths must be supported without duplicate charging or ambiguous payment state.

Deliver a **professional, calm, healthcare-grade workspace** that is easy to scan under pressure: clear hierarchy, minimal cognitive load, predictable actions, and no raw internal identifiers in the UI.

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/pharmacy/` | `data/`, `domain/`, `presentation/` layers exist |
| Workspace UI | `pharmacy_workspace_page.dart` | Order queue, summary cards, order detail, dispense/attest/return/cancel dialogs, formulary stock dialog (read-only drug search) |
| Controller | `pharmacy_workspace_controller.dart` | Realtime refresh, pagination, filters, drug search |
| Repository (partial) | `pharmacy_repository.dart` / `pharmacy_repository_impl.dart` | Workbench, workflow, drug search, prepare/attest/cancel/return dispense |
| Backend workspace API | `backend/src/modules/pharmacy-workspace/` | `/api/v1/pharmacy/workbench`, `/drugs`, order workflow + dispense mutations, `/inventory/stock`, `/inventory/adjust` |
| Standalone APIs | `/api/v1/drugs`, `/formulary-items`, `/inventory-items`, `/stock-movements` | CRUD and list endpoints available |
| Permissions | `AppPermissions.pharmacyRead`, `pharmacyWrite` | Route is permission-gated |
| Order intake (upstream) | `clinical_prescription_action_dialog.dart`, `clinical_workspace_controller.dart` | Clinical/OPD modules create pharmacy orders via repository |
| Prescription-time billing | `clinical_request_billing_panel.dart`, `clinical_request_billing_state.dart` | Pay now vs bill later at order creation (`ClinicalRequestPaymentMode`) |
| Billing workspace | `frontend/lib/features/billing/` | Cashier/billing desk queues and payment recording |
| Order billing fields (API) | `pharmacy.serializer.js` → `mapClinicalOrderBillingFields` | Payment status and billing metadata serialized on pharmacy orders |
| Localization | `frontend/lib/l10n/app_en.arb` | Pharmacy strings partially defined |

### Known gaps to close

- **Inventory management UI** — backend supports stock list and adjust; frontend repository does not expose `getInventoryStock` / `adjustInventoryStock` yet.
- **Drug CRUD** — search exists; create/update/delete flows are not wired in the pharmacy feature.
- **Formulary management** — formulary APIs exist; no dedicated pharmacy UI for formulary create/edit/link-to-drug.
- **Workbench inventory panel** — schema supports `panel=inventory`; frontend always requests `panel=orders`.
- **Billing and payment UI** — workspace shows placeholder `pharmacyBillingGateUnavailable*` messaging; dispense dialog references billing gate info but does not record payment. Mirror the **Radiology** billing-gate pattern (`hasBillingGate`, payment status on detail, `ClinicalRequestBillingPanel` in workflow dialogs).
- **Pending-payment filter** — `PharmacyOrderFilter.pendingPayment` exists but is not backend-backed; wire to order `payment_status` or hide until supported.
- **Filter completeness** — other client-only filters (`partialStock`, `urgent`, `discharge`) are not backend-backed; either implement or hide until supported.
- **Tests** — limited pharmacy-specific widget/controller coverage compared with lab/radiology clinical-action tests.

---

## Scope — Core Capabilities

Implement or finish the following, in priority order.

### 1. Medication order queue and dispensing workflow

**Goal:** Pharmacists can review, process, dispense, partially dispense, attest, return, and cancel orders end-to-end.

**Actions:**

- Keep the primary workspace focused on the **order queue → order detail → action panel** flow.
- Ensure workflow actions respect `PharmacyOrderWorkflow.nextActions` and permission gates (`pharmacyWrite`).
- Support statuses: `ORDERED`, `PARTIALLY_DISPENSED`, `DISPENSED`, `CANCELLED`.
- Dispense dialogs must capture line quantities, optional inventory item mapping, batch ref, and reason/notes where required by API schemas.
- Preserve realtime sync via `RealtimeEventGroups.pharmacyWorkspace`; avoid stale detail when the selected order updates.
- Use display IDs (`displayId`, `displayTitle`) — never surface raw UUIDs to users (see `backend_gap_cleanup_test.dart`).

**Reference APIs:** `GET /pharmacy/orders/:id/workflow`, `POST .../prepare-dispense`, `.../attest-dispense`, `.../cancel`, `.../return`.

### 2. Pharmacy inventory management

**Goal:** View stock levels, identify low/out-of-stock items, and post controlled adjustments.

**Actions:**

- Extend `PharmacyRepository` with `getInventoryStock` and `adjustInventoryStock` mapped to `/pharmacy/inventory/stock` and `/pharmacy/inventory/adjust`.
- Add DTOs/entities for stock rows and adjustment input; follow existing `PharmacyInventoryStock` shapes where possible.
- Provide a dedicated **Inventory** area (secondary panel, tab, or route section) — not buried inside dispense-only dialogs.
- Show: item name/SKU, quantity on hand, reorder/low-stock indicators, facility context when present.
- Adjustment flow: quantity delta, reason (`PURCHASE`, `DISPENSE`, `RETURN`, `DAMAGE`, `EXPIRY`, `OTHER`), optional notes; gate writes with `pharmacyWrite` or `operationsWrite` per backend.
- Subscribe inventory views to relevant realtime events (`inventoryStockUpdated`, `inventoryLowStock`, etc.).

### 3. Drug creation and management

**Goal:** Pharmacists can maintain the drug catalog used by prescriptions and dispensing.

**Actions:**

- Wire CRUD to `/api/v1/drugs` (list already partially covered by `/pharmacy/drugs` search).
- Provide list + create/edit dialog (or slide-over) with validated fields aligned to backend drug schema (name, code, form, strength, etc.).
- Link drug rows to stock status badges consistent with `stock_status` filter values.
- Keep destructive actions (soft delete) behind confirmation and permission checks.

### 4. Formulary creation and management

**Goal:** Tenant-scoped formulary links drugs to orderable, billable catalog entries.

**Actions:**

- Wire list/create/update to `/api/v1/formulary-items`.
- UI: searchable formulary table, add/edit linking drug + formulary metadata per backend schema.
- Differentiate **formulary catalog** (what can be prescribed) from **inventory stock** (what is on hand).
- Reuse patterns from `clinical_catalog_select_helpers.dart` where clinical modules pick formulary drugs.

### 5. Cross-module order intake

**Goal:** Orders from Clinical, OPD, Nursing, and Discharge arrive seamlessly; pharmacy does not re-enter clinical data.

**Actions:**

- Do not duplicate prescription capture in pharmacy — intake stays in `ClinicalPrescriptionActionDialog` and module controllers.
- Pharmacy workspace should show order source context (patient, encounter, prescriber, priority) on detail panels.
- When an order is cancelled upstream, reflect status via refresh/realtime without broken selected-detail state.
- Optional: deep-link from clinical pharmacy order rows to pharmacy workspace with order pre-selected (if routing support is straightforward).
- At prescription time, clinicians may choose **bill later** (patient pays at cashier or pharmacy) or **pay now** (if `billingWrite` is granted). Pharmacy must reflect whichever path was chosen.

### 6. Billing and payment (cashier or pharmacy)

**Goal:** Support the two valid payment paths — **cashier/billing desk** and **pharmacy counter** — with a single source of truth for payment status on each order.

**Business rules:**

| Path | When | Who | Expected behavior |
|------|------|-----|-------------------|
| **Cashier / billing** | Patient pays before or after clinical visit | Billing staff in `features/billing/` | Order shows unpaid/partial until billing records payment; pharmacy sees updated status and may gate dispense until paid (per facility policy). |
| **Pharmacy counter** | Patient pays at dispense time | Pharmacist with `billingWrite` (and `pharmacyWrite`) | Collect payment in pharmacy workspace or dispense dialog using shared billing components; update order payment status before or as part of prepare-dispense. |
| **Paid at prescription** | Clinician selects pay now in `ClinicalPrescriptionActionDialog` | Prescriber / clerk with `billingWrite` | Order arrives with `payment_status` already `PAID` (or partial); pharmacy shows paid state and proceeds to dispense without re-collection. |

**Actions:**

- Parse billing fields from pharmacy order/workflow DTOs (`payment_status`, totals, currency, line-item prices) — backend already exposes these via `mapClinicalOrderBillingFields`.
- Add `hasBillingGate` / `effectivePaymentStatus` (or equivalent) on `PharmacyOrder` entities, following `RadiologyOrder` in `radiology_entities.dart`.
- Replace placeholder billing alerts with real status chips on the order detail header (paid, partial, unpaid, not billed).
- Integrate `ClinicalRequestBillingPanel` (or `showClinicalRequestBillingDialog`) for **record payment at pharmacy** flows; gate on `AppPermissions.billingWrite`.
- Enforce dispense readiness: when billing gate applies, block or warn on prepare-dispense if payment is required and unpaid — match radiology’s `radiologyNextActionConfirmBilling` pattern with pharmacy-specific copy.
- Implement **pending payment** queue filter backed by API (`payment_status` / billing gate), not client-only filtering.
- Ensure billing desk and pharmacy actions update the same order billing record — no duplicate charges; show clear “paid at billing” vs “paid at pharmacy” context when audit metadata exists.
- Reuse `clinicalRequestPaymentStatusLabel`, payment methods, and `ClinicalRequestBillingSubmit.toPayloadMap()` for API consistency.

**Reference:** `radiology_workspace_page.dart` (billing column, detail payment field, billing dialog in workflow), `clinical_prescription_action_dialog.dart` (pay now at order creation), `frontend/lib/features/billing/` (cashier queues).

---

## UI / UX Requirements

Follow `frontend/.cursor/ui-patterns.mdc`, `design-system.mdc`, `components.mdc`, and `layouts.mdc`. Mirror proven workspace patterns from **Lab** and **Radiology** (`AppWorkspace`, `AppListTable`, `AppWorkspaceDetailPanel`, `AppActionPanel`).

### Organization

- **Single primary task per screen region:** queue (left/list), detail (center/right), actions (grouped panel).
- **Progressive disclosure:** summary cards for at-a-glance counts; filters collapsed in advanced filter; complex forms in dialogs.
- **Three logical domains, clearly separated:**
  1. **Operations** — order queue and dispensing (default landing).
  2. **Payment** — payment status on order detail; record-payment action when unpaid and user has `billingWrite` (pharmacy path). Cashier path stays in billing workspace — pharmacy only displays status and gates dispense.
  3. **Catalog & stock** — drugs, formulary, inventory (secondary navigation or workspace sections).
- Use consistent section titles, descriptions, and empty states (localized via `app_en.arb`).

### Simplicity

- Reduce visual noise: avoid duplicate controls, redundant badges, and nested cards.
- Default the queue filter to **ready to dispense** (`ORDERED`); expose other statuses via summary chips or filter.
- Limit table columns to what pharmacists need at a glance; hide optional columns via column visibility.
- Form layouts: one column on narrow viewports; group related fields; show validation inline.
- Action panel: primary action first (Record payment when unpaid and allowed, then Dispense), destructive actions last (Cancel), disabled with tooltip when not allowed (e.g. dispense blocked pending payment).
- Payment UI: one compact billing summary on order detail (status + amount); full payment form only in dialog — avoid repeating billing fields in dispense and detail panels.
- Loading/saving: use existing `AppWorkspace` status tone and `AsyncStateScaffold` patterns — no blocking full-page reloads for minor updates.

### Professional healthcare feel

- Accurate terminology (order, dispense, attest, return — not generic “submit”).
- Audit-friendly: show who/when on workflow history when API provides it.
- Print patient instructions via existing `printFormTemplateDocument` integration.
- Accessibility: semantic labels on search, tables, and action buttons; keyboard-navigable dialogs.

---

## Architecture and Conventions

Follow `frontend/docs/workflows/feature-workflow.md` and `.cursor/` rules.

| Rule | Requirement |
|------|-------------|
| Layering | UI/controllers → repository interface → repository impl → API client. No API calls from widgets. |
| State | Riverpod `AsyncNotifier` controllers; `Result<T>` / `AppFailure` for errors. |
| DTOs | `data/dtos/` with explicit mappers to `domain/entities/`. |
| Localization | Add keys to `app_en.arb` first; run codegen; no hard-coded user strings. |
| Permissions | `AccessGate` / `AppAccessActionGate` for write actions. |
| Shared UI | Prefer `lib/shared/components`, `forms`, `layout` before new widgets. |
| File size | Extract widgets to `presentation/widgets/` when pages grow; keep pages compositional. |
| Tests | Mirror structure under `test/features/pharmacy/`; cover controller transitions, DTO mapping, critical dialogs. |

**Do not** add feature business logic to `core/` or `shared/` unless it is genuinely cross-module (clinical prescription dialog already lives in `shared/clinical_actions/`).

---

## Suggested Implementation Order

1. **Repository + DTO completion** — inventory endpoints, then drug/formulary CRUD contracts.
2. **Controller state** — inventory panel state, formulary/drug mutation loading flags, error surfacing.
3. **Billing + payment** — entity/DTO billing fields, detail status, record-payment dialog, dispense billing gate, pending-payment filter.
4. **UI — dispensing polish** — verify partial dispense, return, and edge cases; simplify action panel layout.
5. **UI — catalog & inventory** — drugs, formulary, stock panels with clear navigation between them.
6. **Integration hardening** — realtime, filter alignment, clinical handoff and billing-desk ↔ pharmacy payment sync smoke paths.
7. **Tests + quality gate** — see below.

Work in small, reviewable increments. One clear responsibility per new file.

---

## Acceptance Criteria

- [ ] Pharmacist can open Pharmacy workspace, filter/search orders, open detail, and complete prepare → attest dispense flow.
- [ ] Partial dispense, return, and cancel paths work with API validation errors shown in UI.
- [ ] Inventory stock is listable; authorized users can post adjustments with reason.
- [ ] Drugs can be created and edited from pharmacy UI; search reflects changes after save.
- [ ] Formulary items can be listed and managed; linked drugs appear in clinical prescription picker.
- [ ] Orders created from Clinical prescription flow appear in pharmacy queue without manual refresh (realtime or sync).
- [ ] Payment status is visible on pharmacy order detail; pending-payment filter works against API-backed status.
- [ ] Unpaid orders can be paid at the **pharmacy counter** (with `billingWrite`) or reflect payment recorded at the **cashier/billing desk** without duplicate charges.
- [ ] Orders prescribed with pay-now billing arrive as paid; bill-later orders remain dispensable only after payment (per billing gate rules).
- [ ] All user-facing strings localized; permissions enforced; no raw internal IDs in production UI.
- [ ] UI is organized into clear Operations, Payment, and Catalog/Stock areas with calm, scannable layout.
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

Add focused tests during development; run the full gate before PR or merge.

---

## Key File References

```
frontend/lib/features/pharmacy/
├── data/dtos/pharmacy_dtos.dart
├── data/repositories/pharmacy_repository_impl.dart
├── domain/entities/pharmacy_entities.dart
├── domain/repositories/pharmacy_repository.dart
└── presentation/
    ├── controllers/pharmacy_workspace_controller.dart
    └── pages/pharmacy_workspace_page.dart

frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart
frontend/lib/shared/clinical_actions/clinical_request_billing_panel.dart
frontend/lib/shared/clinical_actions/clinical_request_billing_state.dart
frontend/lib/features/billing/
frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart  # billing-gate reference

backend/src/modules/pharmacy-workspace/
backend/src/lib/billing/clinical-request-billing.js
backend/src/modules/pharmacy-order/
backend/src/modules/drug/
backend/src/modules/formulary-item/
backend/src/modules/inventory-item/
```
