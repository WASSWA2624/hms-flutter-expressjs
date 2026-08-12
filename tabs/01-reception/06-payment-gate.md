# Reception tab — Payment gate

## 1. Tab strip

- Label: `receptionSectionPaymentGate`
- Icon: `Icons.payments_outlined`
- Count source: `ReceptionPaymentGateState.totalCount` (server/aggregate total; falls back to loaded `entries.length`). When this tab is active and clearance/next-action/provider/source/gender/date/search narrow the list, badge uses the filtered membership total
- Sibling tabs: dedicated unfiltered scope totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.warning` — product-justified outstanding clearance / payment pressure (documented in Payment gate permission tests)
- Deep-link `section`: `payment-gate` (aliases `payment`, `pending_balance_amount`, `pending-payments`)
- Tab gate: `ReceptionPaymentGateAtomPermissions.tab` = ∪ `billing:read` + module `billing-payments`
- **Omitted when unauthorized** (controller not watched)
- Guidance only — never grants cashier mutations

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule → Register**

- Search hint: `receptionPaymentGateSearchHint`
- Filters / Settings: shared labels
- Export: gated by `ReceptionPaymentGateAtomPermissions.export` / `receptionDeskExportRequirement` (∩ `evidence:export`); omitted when denied
- Print (toolbar): `commonPrintActionLabel` → preview-first `printReceptionDeskList` / `PrintDocumentTemplates.registry`; omitted without export/print gate
- Schedule / Register: ∩ `patient:write` (desk strip reuse)
- Date filter: **enabled** — `billingIssuedDateFilterLabel` on entry `issuedAt` (latest invoice `timelineAt`)
- Collect / Receive payment: **not mounted** (Billing owns cashier)

## 3. Table

- Row model: `_ReceptionDeskRow.paymentGate(ReceptionPaymentGateEntry)`
- Row select → read-only billing guidance detail
- Default columns (prefer **5** data columns; next-action is read-only guidance):
  1. Patient (name + identifier subtitle only)
  2. Encounter (`billingEncounterLabel`) — identifier only
  3. Current step / clearance (`receptionCurrentStepLabel` + `billingClearanceLabel`)
  4. Amount due (`billingAmountDueColumn`)
  5. Source / services (`billingSourceColumn`)
  6. Next action guidance (`opdNextActionFilterLabel` / Billing guidance) — if `receptionPaymentGateShowsNextActionColumn`
- Column choices (Settings):
  - Patient ID, Gender (`patientsGenderColumnLabel`), DOB (`patientsDobColumnLabel`), Invoice (`billingInvoiceColumn`)
- Reset restores the defaults (+ next-action when readable)

## 4. Advanced filters / search fields

Same filter model as the table and active tab count:

- Groups: Status / clearance (`billingStatusFilterLabel`), Next action, Provider (when values exist on rows), Source (`billingSourceFilterLabel`), Gender (`patientsGenderFilterLabel`)
- Search fields: patient, record, staff, reason, status, **service**, **invoice**
- Date range on issued-at (`billingIssuedDateFilterLabel`)

## 5. Primary / secondary / row actions

- Strip: Schedule, Register only
- Row: open read-only detail (Close)
- No Collect / Receive payment button (even with `billing:write`)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Billing guidance (`receptionBillingGuidanceTitle`) | Reception-owned `_ReceptionPaymentGateDetailDialog` |
| Schedule / Register | shared |

## 7. Nested / follow-on

- Detail is terminal for mutations: patient/encounter context panel + invoice cards (`BillingWorkItem` via billing widgets) + Close
- No nested collect / adjust / refund dialogs
- No Billing workspace handoff button required for compliance
- Schedule/Register nest same as other tabs

## 8. Forms (summary)

- Detail: read-only `OpdWorkflowContextPanel` + `receptionPaymentGateReadOnlyBody` + outstanding invoice cards (source, amounts) — no submit fields
- Schedule / Register: shared

## 9. Print / labels / preview

- Table Print: present when authorized; preview before device print; options aligned to exportable guidance/invoice summary fields
- Detail dialog: no print / collect surface

## 10. Loading / empty / error / success

- Empty: `receptionPaymentGateEmptyTitle` / `receptionPaymentGateEmptyBody`
- Controller failure with no data: error `AppStateView` + Retry on payment-gate controller
- Success snackbars only for Schedule/Register strip paths
- After strip mutations: refresh table + all visible tab counts

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / filters / detail / next-action label / close | `billing:read` + `billing-payments` |
| Export / Print | ∩ `evidence:export` |
| Register / Schedule | ∩ `patient:write` |
| Collect / Receive payment | ∩ `billing:write` documented — **not mounted** |
| Hard delete | not mounted |
| Nested cross-module | n/a |
