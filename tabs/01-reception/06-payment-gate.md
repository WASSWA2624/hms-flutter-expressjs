# Reception tab — Payment gate

## 1. Tab strip

- Label: `receptionSectionPaymentGate`
- Icon: `Icons.payments_outlined`
- Count source: `paymentGate.entries.length` (loaded payment-gate list)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `payment-gate` (aliases `payment`, `pending_balance_amount`, `pending-payments`)
- Tab gate: `ReceptionPaymentGateAtomPermissions.tab` = ∪ `billing:read` + module `billing-payments`
- **Omitted when unauthorized** (controller not watched)
- Guidance only — never grants cashier mutations

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `receptionPaymentGateSearchHint`
- Filters / Settings / Export: present
- Print (toolbar): **absent**
- Schedule / Register: ∩ `patient:write` (desk strip reuse)
- **Date filter: intentionally omitted** (`enableDateFilter: false`) — payment gate still exposes arrival-date label helper unused for toolbar date
- Collect / Receive payment: **not mounted** (Billing owns cashier)

## 3. Table

- Row model: `_ReceptionDeskRow.paymentGate(ReceptionPaymentGateEntry)`
- Row select → read-only billing guidance detail
- Default columns:
  1. Patient
  2. Encounter (`billingEncounterLabel`) — subtitle services
  3. Current step / clearance (`receptionCurrentStepLabel` + `billingClearanceLabel`)
  4. Next action guidance (`opdNextActionFilterLabel`) — if `receptionPaymentGateShowsNextActionColumn` (read-only)
  5. Amount due (`billingAmountDueColumn`)
- Column choices:
  - Patient ID, Gender (`patientsGenderColumnLabel`), DOB (`patientsDobColumnLabel`), Source (`billingSourceColumn`), Invoice (`billingInvoiceColumn`)

## 4. Advanced filters / search fields

- Groups: Status (`billingStatusFilterLabel` / clearance), Next action, Provider, Source (`billingSourceFilterLabel`), Gender (`patientsGenderFilterLabel`)
- Search fields: patient, record, staff, reason, status, **service**, **invoice**
- No date filter control on toolbar

## 5. Primary / secondary / row actions

- Strip: Schedule, Register only
- Row: open read-only detail (Close)
- No Collect / Receive payment button

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Billing guidance (`receptionBillingGuidanceTitle`) | Reception-owned `_ReceptionPaymentGateDetailDialog` |
| Schedule / Register | shared |

## 7. Nested / follow-on

- Detail is terminal for mutations: patient/encounter context panel + invoice cards (`BillingWorkItem` via billing widgets) + Close
- No nested collect / adjust / refund dialogs
- Schedule/Register nest same as other tabs

## 8. Forms (summary)

- Detail: read-only `OpdWorkflowContextPanel` + `receptionPaymentGateReadOnlyBody` + outstanding invoice cards (source, amounts) — no submit fields
- Schedule / Register: shared

## 9. Print / labels / preview

- **Absent** on this tab and its detail dialog

## 10. Loading / empty / error / success

- Empty: `receptionPaymentGateEmptyTitle` / `receptionPaymentGateEmptyBody`
- Controller failure with no data: error `AppStateView` + Retry on payment-gate controller
- Success snackbars only for Schedule/Register strip paths

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / filters / detail / next-action label / close | `billing:read` + `billing-payments` |
| Register / Schedule | ∩ `patient:write` |
| Collect / Receive payment | ∩ `billing:write` documented — **not mounted** |
| Hard delete | not mounted |
| Nested cross-module | n/a |
