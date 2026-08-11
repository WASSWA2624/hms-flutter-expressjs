# Billing — complete screen blueprint

This document is the **source of truth** for the **Billing** workspace. Implement it the same way **Human resources** (`/hr`) is implemented: one gated workspace page, desk tabs, `AppListTable` chrome, and row → details dialog with permission-gated actions.

**Billing is the central desk for all facility billing activity.** Clinical modules post charges here; cashiers issue and collect here; insurers and approvals are decided here; price book and patient ledgers are managed here. Do not scatter parallel billing UIs.

| | |
|---|---|
| **Nav / app bar title** | Billing |
| **Route** | `/billing` |
| **Module** | `billing-payments` (+ `insurance-claims` for claims tab) |
| **Mirror** | `/hr` (`HrWorkspacePage` → `BillingWorkspacePage`) |

---

## 1. Screen shell (exact HR flow)

```
AppAccessGate (billing route entry)
└── AsyncStateScaffold
    ├── appBarTitle: "Billing"
    ├── loadingTitle: "Loading billing workspace"
    ├── loadingBody: "Loading invoices and payment queues..."
    └── ResponsivePage (PageMaxWidth.dataHeavy, scrollable: false)
        └── Column
            ├── AppTabStrip  (icon + label + count; permission-filtered)
            └── Expanded → active tab body
```

Rules (match HR):

1. No page-level app-bar trailing actions. Actions live in the search bar and dialogs.
2. First viewport = tab strip + one table/panel. No KPI card dashboard above the table.
3. Tab counts: info for All; warning for actionable queues; **danger** for Overdue.
4. Unauthorized current tab falls back to the first allowed tab (prefer **All billing work items**).
5. Mutations use snackbars; clear `lastFailure` in UI — no sticky error banner between strip and table.
6. Realtime + adaptive poll refresh the active queue (same controller pattern as HR).

### Shared widgets (required)

| Concern | Widget |
|---|---|
| Tabs | `AppTabStrip` / `AppTabItem` |
| Tables | `AppListTable` + `AppListTableColumnVisibilityController` + export |
| Search chrome | `AppSearchBar` — Filter → Table settings → Export → trailing |
| Filters | `AppSearchBarFilterGroup` / `FilterChoice` |
| Dialogs | `showAppDialog` / `AppDialog` |
| Detail chrome | `AppPatientDetails`, `AppInfoTileGrid`, `AppQuickActions`, `AppPermissionActionItem` |
| Mutations | `showAppWorkspaceMutationDialog` / confirm dialogs |
| Layout | `AsyncStateScaffold`, `ResponsivePage`, `AppAccessGate`, `AppWorkspaceStatePanel` |

### Search-bar action order (every table tab)

```
[ Search field ]  [ Filters ]  [ Table settings ]  [ Export ]  [ …trailing tab actions ]
```

---

## 2. Desk sections (tabs)

Introduce a desk-section enum (HR: `HrDeskSection`) — **`BillingDeskSection`**.

URL: `/billing?section=<slug>` (alias `?tab=`). Work-queue tabs also sync `?queue=<serverQueue>`.

| # | Tab label | Enum | `?section=` | Body type | Count | Count tone |
|---|---|---|---|---|---|---|
| 1 | **All billing work items** | `all` | `all` | Work queue | Total open work | info |
| 2 | **Ready to issue** | `needsIssue` | `needs-issue` | Work queue | Drafts ready | warning |
| 3 | **Awaiting payment** | `pendingPayment` | `awaiting-payment` | Work queue | Open balances | warning |
| 4 | **Payments** | `payments` | `payments` | Payments table | Payments today (or page total) | info |
| 5 | **Claims pending** | `claimsPending` | `claims-pending` | Work queue | Open claims/pre-auth | warning |
| 6 | **Approval required** | `approvalRequired` | `approval-required` | Work queue | Pending approvals | warning |
| 7 | **Overdue** | `overdue` | `overdue` | Work queue | Overdue invoices | danger |
| 8 | **Patient ledgers** | `patientLedgers` | `patient-ledgers` | Patient balance table | Patients with balance | warning |
| 9 | **Price book** | `priceBook` | `price-book` | CRUD panel | Active entries | info |
| 10 | **Financial analytics** | `analytics` | `analytics` | Analytics panel | — (no badge) | — |

Aliases: `pending-payment` → awaiting-payment; `approvals` → approval-required; `ledgers` → patient-ledgers; `pricing` → price-book.

**Why these tabs:** work queues cover cashier workflows (HR leave/swap style). **Payments**, **Patient ledgers**, and **Price book** are directory/admin surfaces (HR staff/positions style). **Financial analytics** is the in-desk reporting surface (not a separate first product).

---

## 3. Common work-queue table contract

Used by tabs 1–3, 5–7 (All, Ready to issue, Awaiting payment, Claims pending, Approval required, Overdue).

### Chrome

| Control | Spec |
|---|---|
| **Search** | Debounced ~350ms. Hint: *Patient, ID, invoice, encounter, email, or phone*. Semantic: *Search billing worklist*. Clear: *Clear billing search*. |
| **Filters** | Button label *Filters*. Dialog/sheet title *Billing filters*. Clear *Clear*. |
| **Filter groups** | **Patient name or ID** (text) · **Invoice #** (text) · **Encounter** (text) · **Source** (Any / OPD / Emergency / Inpatient / Laboratory / Radiology / Pharmacy / Theatre / Clinical) · **Status** (Any / Draft / Issued / Partially paid / Paid / Overdue / Cancelled / Pending approval / Approved / Rejected / Claim submitted / Authorization pending / Authorization denied — show only statuses relevant to the tab) · **Issued date** (from–to) |
| **Table settings** | Column visibility; persist key `billing_<section>_v1` |
| **Export** | Built-in `AppListTable` export of filtered rows |
| **Pagination** | Previous page / Next page + page label |
| **Empty** | Title *No billing items*. Body = tab-specific empty string below. |
| **Row click** | Open **Billing item detail** dialog (live reload of work item). |
| **Next action column** | Primary happy-path button; disabled (not hidden) when permission denied. |

### Available columns (pool)

| Column ID | Header | Notes |
|---|---|---|
| `patient` | Patient | Name + ID subtext |
| `invoice` | Invoice | Human-friendly invoice # |
| `encounter` | Encounter | Encounter / visit ref |
| `source` | Source | OPD, Pharmacy, … |
| `amountDue` | Amount due | Balance |
| `amount` | Amount | Gross / total |
| `paid` | Paid | Net paid |
| `patientShare` | Patient share | Coverage split |
| `insurerShare` | Insurer share | Coverage split |
| `scheme` | Scheme | Coverage plan |
| `status` | Status | Badge |
| `updated` | Updated | Relative/absolute |
| `age` | Age | Days since issue / due |
| `insurer` | Insurer | Claims tab |
| `claimStatus` | Claim status | Claims tab |
| `requestType` | Request type | Approvals tab |
| `requester` | Requested by | Approvals tab |
| `reason` | Reason | Approvals tab |
| `nextAction` | Next action | Inline button |

---

## 4. Tab specifications

### 4.1 All billing work items (`all`)

**Purpose:** Cross-queue inbox — every open billing action in one list.

| | |
|---|---|
| **Default columns** | Patient · Invoice · Amount due · Status · Next action |
| **Empty body** | *No invoices or billing actions in this queue.* |
| **Trailing actions** | **Close shift** · **Close day** · **Quick charge** (write) |
| **Next-action priority** | Approve → Issue → Receive payment → Submit claim → Record insurer response → Approve authorization → Request refund → Request adjustment → Request void → Send |
| **Row click** | Billing item detail (kind-aware: invoice / claim / approval / pre-auth) |

---

### 4.2 Ready to issue (`needs-issue`)

**Purpose:** Draft invoices waiting to become collectible.

| | |
|---|---|
| **Default columns** | Patient · Invoice · Encounter · Status · Next action |
| **Empty body** | *No draft invoices waiting to be issued.* |
| **Trailing actions** | **Close shift** · **Close day** · **Issue selected** (bulk, write) · **Quick charge** |
| **Next action** | **Issue** (when `canIssue`) |
| **Row click** | Invoice detail → Issue / Adjust / Void / Send / View ledger / Print / Download |

---

### 4.3 Awaiting payment (`awaiting-payment`)

**Purpose:** Issued / partially paid invoices with patient (or facility) balance due.

| | |
|---|---|
| **Default columns** | Patient · Invoice · Amount due · Status · Next action |
| **Empty body** | *No issued or partially paid invoices awaiting payment.* |
| **Trailing actions** | **Close shift** · **Close day** · **Receive payment** (opens pay flow for focused/selected row when single) |
| **Next action** | **Receive payment** |
| **Deep link** | `?section=awaiting-payment&action=pay&id=<invoiceId>` auto-opens Receive payment |
| **Row click** | Invoice detail → Pay / Refund / Adjust / Void / Send / Ledger / Print / Download |

---

### 4.4 Payments (`payments`) — directory tab (HR Staff analogy)

**Purpose:** Central payment history and receipt desk. Not only nested under invoices.

| | |
|---|---|
| **Body** | `AppListTable<BillingPaymentRow>` |
| **Search hint** | *Payment ref, invoice, patient, payer* |
| **Filters** | Method · Status (Pending / Settled / Refunded / Failed) · Paid date from–to · Patient · Invoice |
| **Default columns** | Paid at · Payment # · Patient · Invoice · Method · Amount · Status · Next action |
| **Empty** | *No payments match the current filters.* |
| **Trailing actions** | **Close shift** · **Close day** · **Receive payment** (pick patient/invoice) |
| **Next action** | Settled → **Request refund** · Pending → **Reconcile** · Refunded → **View receipt** |
| **Row click** | **Payment detail** dialog |

---

### 4.5 Claims pending (`claims-pending`)

**Purpose:** Insurer share, claim submission, remittance, and pre-authorization work.

| | |
|---|---|
| **Module gate** | `billing-payments` ∩ `insurance-claims` |
| **Default columns** | Patient · Invoice · Encounter · Status · Next action |
| **Optional columns** | Insurer · Claim status · Patient share · Insurer share · Scheme |
| **Empty body** | *No insurance claims or authorizations waiting on a payer response.* |
| **Trailing actions** | **Close shift** · **Close day** |
| **Next action** | **Submit claim** · **Record insurer response** · **Approve authorization** (by row kind) |
| **Row click** | Claim / Pre-auth / Insured invoice detail |

---

### 4.6 Approval required (`approval-required`)

**Purpose:** Refunds, voids, adjustments, write-offs, shift/day close variances awaiting decision.

| | |
|---|---|
| **Default columns** | Patient · Invoice · Amount due · Status · Next action |
| **Optional columns** | Request type · Requested by · Reason |
| **Empty body** | *No refunds, voids, or adjustments waiting for approval.* |
| **Trailing actions** | **Close shift** · **Close day** |
| **Next action** | **Approve** (Reject lives in detail) |
| **Row click** | **Approval request** detail → Approve / Reject / View ledger |

---

### 4.7 Overdue (`overdue`)

**Purpose:** Past-due balances and collection follow-up (HR Unassigned / overdue shifts analogy).

| | |
|---|---|
| **Default columns** | Patient · Invoice · Amount due · Status · Next action |
| **Optional columns** | Age (days overdue) · Source |
| **Empty body** | *No overdue patient invoices in this queue.* |
| **Trailing actions** | **Close shift** · **Close day** · **Send reminders** (bulk send when selection exists) |
| **Next action** | **Receive payment** |
| **Row click** | Invoice detail → Pay / Adjust (waive) / Refund / Void / Send (dunning) / Ledger / Print |

---

### 4.8 Patient ledgers (`patient-ledgers`) — directory tab (HR Staff analogy)

**Purpose:** Browse patients by financial position; open the full ledger without hunting invoices.

| | |
|---|---|
| **Body** | `AppListTable<BillingPatientLedgerSummary>` |
| **Search hint** | *Patient name, ID, phone, email* |
| **Filters** | Balance state (Any / Has balance / Cleared / Deferred / Blocked) · Last activity from–to · Source |
| **Default columns** | Patient · Invoiced · Paid · Balance · Clearance · Updated · Next action |
| **Empty** | *No patients match the current ledger filters.* |
| **Trailing actions** | **Quick charge** · **Receive payment** |
| **Next action** | Has balance → **Receive payment** · Cleared → **View ledger** · Blocked → **View ledger** |
| **Row click** | **Patient ledger** dialog (same dialog used from invoice detail) |

---

### 4.9 Price book (`price-book`) — CRUD panel (HR Positions analogy)

**Purpose:** Catalogue rates Billing uses to price charge events. Admin surface lives in Billing, not a separate app.

| | |
|---|---|
| **Body** | Price book panel (`AppListTable<PriceBookEntry>`) |
| **Search hint** | *Catalogue item, code, scheme, insurer* |
| **Filters** | Catalog type · Payment mode (Cash / Insured / Mixed) · Active/Inactive · Facility scope · Scheme |
| **Default columns** | Item · Catalog type · Payment mode · Unit price · Currency · Scheme / Insurer · Effective · Status · Actions |
| **Empty** | *No price book entries match the current filters.* |
| **Trailing actions** | **Add price** (write/pricing admin) |
| **Row actions** | Edit · Deactivate / Activate · Delete (soft) |
| **Row click** | **Price book entry** detail / edit dialog |

---

### 4.10 Financial analytics (`analytics`)

**Purpose:** In-desk collections / expenditures / surplus for the selected period. Not the primary cashier viewport; still owned by Billing.

| | |
|---|---|
| **Body** | `BillingFinancialAnalyticsPanel` (no work-queue table) |
| **Period controls** | Day · Month · Year · Custom |
| **KPIs** | Collections · Expenditures · Operating surplus · Refunds · Write-offs · Net collections · Issued invoices · Open invoices |
| **Sections** | More detail · Collections by method · Collections trend · Revenue mix |
| **Trailing / panel action** | **Open reports** (`reports:read`) |
| **Empty** | *No collections or expenditures were recorded for this period.* |

---

## 5. Trailing action catalog

| Button | Label | Tabs | Opens | Permission |
|---|---|---|---|---|
| Close shift | *Close shift* | All queue tabs + Payments | **Close shift** modal | `billing:write` ∩ module |
| Close day | *Close day* | All queue tabs + Payments | **Close day** modal | same |
| Quick charge | *Quick charge* | All, Ready to issue, Patient ledgers | **Quick charge** modal | `billing:write` |
| Issue selected | *Issue selected* | Ready to issue | Bulk issue confirm | `billing:write` |
| Receive payment | *Receive payment* | Awaiting payment, Payments, Patient ledgers | **Receive payment** modal | `billing:write` |
| Send reminders | *Send reminders* | Overdue | Bulk **Send invoice** | `billing:write` |
| Add price | *Add price* | Price book | **Price book entry** create | pricing write |
| Open reports | *Open reports* | Analytics | Reports module | `reports:read` |

---

## 6. Next-action buttons (row)

| Label | When | Opens |
|---|---|---|
| **Issue** | Draft invoice, `canIssue` | Issue invoice modal (notes) → posts issue |
| **Receive payment** | Balance due, `canReceivePayment` | Receive payment modal |
| **Request refund** | Paid/partial, `canRequestRefund` | Refund request modal |
| **Request adjustment** | Open invoice, `canRequestAdjustment` | Adjustment request modal |
| **Request void** | Issued+, `canRequestVoid` | Void request modal |
| **Send** | Issued invoice | Send invoice modal (email) |
| **Approve** | Pending approval, `canApproveOrReject` | Approve modal (notes) |
| **Submit claim** | Claim ready, `canSubmitClaim` | Submit claim (notes) |
| **Record insurer response** | Claim submitted, `canReconcileClaim` | Claim reconcile modal |
| **Approve authorization** | Pre-auth pending | Pre-auth approve modal |
| **Reconcile** | Pending payment row (Payments tab) | Payment reconcile |
| **View receipt** | Settled payment | Print/download receipt |
| **View ledger** | Patient ledger tab / cleared rows | Patient ledger dialog |

Mount **Next action** column when user has write **or** approve **or** claims write (Approval tab requires approve; Claims tab requires claims write).

---

## 7. Modals / dialogs (complete)

Every modal uses `AppDialog` / `showAppWorkspaceMutationDialog` patterns from HR. Titles and primary buttons below are canonical.

### 7.1 Billing item detail (row click — work queues)

**Title by kind**

| Kind | Title |
|---|---|
| Invoice | *Invoice detail* |
| Generic work item | *Billing item* |
| Claim | *Insurance claim* |
| Approval | *Approval request* |
| Pre-authorization | *Pre-authorization* |

**Chrome**

- Live status chip (*Live* / *Posting*)
- Patient header (`AppPatientDetails`) with **View ledger**
- Footer / quick actions: contextual set below
- Print / Download on invoice kinds (*Print invoice* · Download PDF tooltip *Download invoice PDF*)

**Body sections (invoice)**

1. **Financial summary** — Total amount · Amount paid · Balance · Effective total · Payments received · Net paid · Refunds · Invoice status · Payment status · Age · Clearance badge · Encounter · Coverage plan · Patient/Insurer share · Scheme  
2. **Line items** table — Description · Qty · Unit price · Department · Amount · Patient share · Insurer share · Scheme. Empty: *No line items returned for this invoice.*  
3. **Payments** — payment rows (method, amount, ref, paid at). Empty: *No payments recorded for this invoice.*  
4. **Adjustments** — adjustment rows. Empty: *No billing adjustments recorded.*

**Body sections (claim / approval / pre-auth)** — `AppInfoTileGrid` overview tiles (status, amounts, requester, reason, linked invoice, coverage, approved/consumed amounts) + related invoice summary when linked.

**Quick actions (permission + capability gated)**

| Action | Label |
|---|---|
| Issue | *Issue* / *Issue invoice* |
| Receive payment | *Receive payment* |
| Request refund | *Request refund* |
| Request adjustment | *Request adjustment* |
| Request void | *Request void* / *Void* |
| Send | *Send* / *Send invoice* |
| Approve | *Approve* |
| Reject | *Reject* |
| Submit claim | *Submit claim* |
| Record insurer response | *Record insurer response* |
| Approve authorization | *Approve authorization* |
| Deny authorization | *Deny authorization* |
| Finalize financial clearance | *Finalize financial clearance* (when `canFinalizeEncounterBilling`) |
| View ledger | *View ledger* |

---

### 7.2 Receive payment

| | |
|---|---|
| **Title** | *Receive payment* |
| **Context** | Due amount · Scheme · Patient share · Insurer share |
| **Fields** | Amount received · Currency · Payment method · Reference (*Mobile money, card, or bank reference*) · Payer (*Patient, sponsor, insurer, or contact*) · Generate receipt after payment (toggle) |
| **Methods** | Cash · Credit card · Debit card · Prepaid card · Gift card · Voucher · Bank check · Mobile money · Bank transfer · Insurance · Other |
| **Primary** | *Receive payment* |
| **Secondary** | Cancel |

---

### 7.3 Issue invoice

| | |
|---|---|
| **Title** | *Issue invoice* |
| **Fields** | Notes (optional) |
| **Primary** | *Issue* |

---

### 7.4 Send invoice

| | |
|---|---|
| **Title** | *Send invoice* |
| **Fields** | Recipient email · Notes |
| **Primary** | *Send* |
| **Note** | If still DRAFT, issue first then send |

---

### 7.5 Request refund

| | |
|---|---|
| **Title** | *Request refund* |
| **Fields** | Payment (select) · Refund amount · Reason (required) · Notes |
| **Primary** | *Request refund* |
| **Result** | May post immediately or create approval (*Submitted. Pending approval before it takes effect.*) |

---

### 7.6 Request adjustment

| | |
|---|---|
| **Title** | *Request adjustment* |
| **Fields** | Adjustment amount (+/-) · Applied status (Issued / Partial / Paid / Draft) · Reason (required) · Notes |
| **Primary** | *Request adjustment* |
| **Covers** | Discount, price correction, waive, credit note |

---

### 7.7 Request void

| | |
|---|---|
| **Title** | *Void invoice* |
| **Fields** | Void reason (required) · Notes |
| **Primary** | *Request void* |

---

### 7.8 Approve / Reject

| | Approve | Reject |
|---|---|---|
| **Title** | *Approve* | *Reject* |
| **Fields** | Notes (optional) | Reason (required) · Notes |
| **Primary** | *Approve* | *Reject* |

---

### 7.9 Submit claim

| | |
|---|---|
| **Title** | *Submit claim* |
| **Fields** | Notes (optional) |
| **Primary** | *Submit claim* |

---

### 7.10 Record insurer response (claim reconcile)

| | |
|---|---|
| **Title** | *Record insurer response* |
| **Fields** | Status (Approved / Rejected / Partial / Paid) · Settlement amount (when Partial or Paid) · Notes |
| **Primary** | *Record insurer response* |

---

### 7.11 Pre-authorization decide

| | Approve | Deny |
|---|---|---|
| **Title** | *Approve authorization* | *Deny authorization* |
| **Fields** | Approved amount (approve) · Notes | Reason · Notes |
| **Shows** | Approved amount · Consumed amount (context) | |

---

### 7.12 Close shift

| | |
|---|---|
| **Title** | *Close shift* |
| **Fields** | Expected amount · Actual amount · Notes · Submit for approval (toggle) |
| **Primary** | *Close shift* |

---

### 7.13 Close day

| | |
|---|---|
| **Title** | *Close day* |
| **Fields** | Notes · Submit for approval (toggle) |
| **Primary** | *Close day* |

---

### 7.14 Patient ledger

| | |
|---|---|
| **Title** | *Patient ledger* |
| **Header** | Patient identity + summary: Invoiced · Paid · Balance |
| **Body** | Chronological entries (charges, invoices, payments, refunds, adjustments) with realtime refresh |
| **Empty** | *No ledger entries for this patient in the selected period.* |
| **Actions** | **Receive payment** · **Quick charge** · Close |

---

### 7.15 Payment detail (Payments tab row)

| | |
|---|---|
| **Title** | *Payment* |
| **Sections** | Overview tiles (amount, method, status, paid at, reference, payer) · Linked invoice summary · Refunds |
| **Actions** | **Request refund** · **Reconcile** (if pending) · **View ledger** · Print / Download receipt · Open linked invoice detail |

---

### 7.16 Quick charge

| | |
|---|---|
| **Title** | *Quick charge* |
| **Fields** | Patient · Catalogue item / free-text description · Qty · Unit price (price-book resolved when possible) · Payment mode · Notes |
| **Primary** | *Create charge* / *Create invoice* |
| **Result** | Draft invoice appears on **Ready to issue** (or issued if policy allows walk-in collect) |

---

### 7.17 Finalize financial clearance

| | |
|---|---|
| **Title** | *Finalize financial clearance* |
| **Body** | *Linked charges are settled. Confirm financial clearance for this encounter.* |
| **Primary** | Confirm |
| **Effect** | Clears Billing gate for discharge / release flows |

---

### 7.18 Price book entry (create / edit / detail)

| | |
|---|---|
| **Title** | *Add price* / *Edit price* / *Price book entry* |
| **Fields** | Catalog type · Catalog item · Payment mode · Unit price · Currency · Coverage plan · Insurer · Billing entity · Effective from/to · Active · Notes |
| **Actions** | Save · Deactivate · Delete |

---

### 7.19 Bulk confirms

| Modal | When |
|---|---|
| Issue selected | Ready to issue trailing bulk |
| Send reminders | Overdue trailing bulk |
| Delete / restore confirms | Price book destructive actions |

---

## 8. Clearance states (badges)

Shown on detail headers and Patient ledgers:

| State | Label |
|---|---|
| Cleared | *Cleared* |
| Partially paid | *Partially paid* |
| Deferred | *Deferred* |
| Insured | *Insured* |
| Pending authorization | *Pending authorization* |
| Blocked | *Blocked* |

---

## 9. Permissions (HR atom pattern)

Gate route, tabs, chrome, and each button via `Billing*AtomPermissions` (same idea as `Hr*AtomPermissions`).

| Layer | Requirement |
|---|---|
| Route entry | `billing:read` ∪ `billing:write` ∩ module `billing-payments` |
| Work-queue tabs (non-claims) | `billing:read` ∩ module |
| Claims pending | `billing:read` ∩ `billing-payments` ∩ `insurance-claims` |
| Payments / Patient ledgers | `billing:read` ∩ module |
| Price book | `billing:read` ∩ module (writes need pricing/admin write) |
| Analytics | `billing:read`; charts / Open reports need `reports:read` |
| Issue / pay / refund / adjust / void / send / close / quick charge | `billing:write` ∩ module |
| Approve / Reject | `billing:write` ∩ `financial:approve` ∩ module |
| Claim / pre-auth mutations | `billing:write` ∩ `insurance-claims` |
| Print / Download | `billing:read` |

Hide tabs the user cannot see. Disable (do not hide) next-action buttons when denied.

---

## 10. Deep links / URL sync (HR pattern)

Parse `BillingWorkspaceQuery.fromUri`:

| Query key | Effect |
|---|---|
| `section` / `tab` | Select desk section |
| `queue` | Select work queue (wins over section when both disagree) |
| `search` / `q` | Prefill search |
| `id` / `invoiceId` | Open detail after load |
| `patient` / `patientId` | Open patient ledger or filter |
| `paymentId` | Open payment detail on Payments tab |
| `action=pay` | Auto-open Receive payment when allowed |

Write URL with `GoRouter.replace` on tab change:

`/billing?section=<slug>&queue=<serverQueue>`  
(omit `queue` for Payments, Patient ledgers, Price book, Analytics).

---

## 11. Controller / data flow (mirror HR)

```
billingWorkspaceControllerProvider (AsyncNotifier → Result<BillingWorkspaceState>)
  ├── initial load: workspace overview + active section data + references
  ├── realtime: Billing event group; defer while isMutating
  ├── applySection / applyQueue / applySearch (debounce) / applyFilters / changePage
  ├── mutations: issue, pay, refund, adjust, void, send, approve, reject,
  │             submitClaim, reconcileClaim, preAuth, closeShift, closeDay,
  │             quickCharge, priceBook CRUD, finalizeClearance
  └── post-mutation: snackbar + targeted refresh (queue / payments / ledger / detail)
```

Success copy:

- *Billing action saved.*
- *Submitted. Pending approval before it takes effect.*
- *Invoice document saved.* / *Invoice document could not be saved on this device.*

---

## 12. Domain ownership (central desk)

Billing owns or orchestrates:

| Area | Entities / APIs |
|---|---|
| Invoices | `invoice`, `invoice_item`, issue / send / void-request / document |
| Charges | `billable_charge_event`, Quick charge, clinical posting intake |
| Collections | `payment`, receive-payment, reconcile, Close shift / day |
| Reversals | `refund`, refund-request |
| Adjustments | `billing_adjustment`, adjustment request |
| Approvals | `billing_approval`, approve / reject |
| Insurance | `insurance_claim`, `pre_authorization`, coverage split |
| Pricing | `price_book_entry`, `pricing_rule`, scheme offers |
| Patient money view | Patient ledger endpoint |
| Analytics | `/billing/financial-analytics` |

Clinical modules **create charges**; they must deep-link into Billing for issue/pay/clearance — not maintain a second cashier UI.

---

## 13. Implementation map (files)

Mirror HR layout:

```
features/billing/
  domain/entities/
    billing_entities.dart          # BillingDeskSection, queries, work items
    billing_*_financial_inventory.dart
  data/
    dtos/ billing_dtos.dart
    repositories/ billing_repository_impl.dart
  presentation/
    billing_access.dart
    controllers/ billing_workspace_controller.dart
    pages/ billing_workspace_page.dart
    widgets/
      billing_detail_widgets.dart
      billing_receive_payment_dialog.dart
      billing_form_dialogs.dart
      billing_ledger_dialog.dart
      billing_payment_detail_dialog.dart      # Payments tab
      billing_payments_panel.dart            # Payments tab table
      billing_patient_ledgers_panel.dart     # Patient ledgers tab
      billing_price_book_panel.dart          # Price book tab
      billing_financial_analytics_panel.dart
      billing_quick_charge_dialog.dart
      billing_workspace_table_support.dart
      billing_support.dart
```

Reuse: `AppListTable`, `AppTabStrip`, `AppDialog`, `AppQuickActions`, patient quick-charge helpers where they already exist.

---

## 14. Acceptance checklist

### Shell
- [ ] Nav + title = **Billing**; route `/billing`
- [ ] `AppAccessGate` + `AsyncStateScaffold` + `ResponsivePage` + `AppTabStrip` with counts
- [ ] No card dashboard above the table

### Tabs
- [ ] All ten desk sections exist, permission-filtered, deep-linkable
- [ ] Work-queue tabs use shared table contract (search → Filters → Table settings → Export → trailing)
- [ ] Payments / Patient ledgers / Price book are first-class tables (not dialog-only)
- [ ] Financial analytics is a Billing tab (not only Reports)

### Tables
- [ ] Default columns match §4 per tab
- [ ] Next action column follows §6
- [ ] Empty states use the tab-specific bodies

### Modals
- [ ] Row click opens the correct detail dialog (§7.1 / 7.15 / ledger / price book)
- [ ] Every trailing and next action opens the modal defined in §7
- [ ] Approve / refund / void / adjust can land on Approval required when policy requires

### Central ownership
- [ ] All money mutations post through Billing APIs only
- [ ] Clinical deep-links land on the correct Billing tab/action
- [ ] Shift/day close, ledger, price book, and analytics are reachable from Billing without leaving the desk

### HR parity
- [ ] Same chrome order, dialog style, permission atoms, URL sync, and controller mutate/refresh flow as `/hr`

---

## 15. Out of scope

| Item | Where it lives |
|---|---|
| Tenant SaaS subscriptions | `/subscriptions` |
| Full general ledger / chart of accounts | Future **Accounts** module (`accounts.md`) |
| Clinical order entry | Clinical modules (they only post charges into Billing) |
| Standalone Claims product beyond this desk | Optional `/claims` may deep-link into Billing **Claims pending** |

---

## 16. HR → Billing mapping (quick reference)

| HR | Billing |
|---|---|
| Human resources | Billing |
| Staff members | Patient ledgers |
| Positions | Price book |
| Leave / Swap / Unassigned / Roster queues | Ready to issue / Awaiting payment / Claims / Approvals / Overdue |
| Pay & Compensation | Payments (+ Awaiting payment) |
| Staff detail dialog | Invoice / Payment / Approval detail + Patient ledger |
| Generate payroll / Request leave trailing | Close shift/day, Quick charge, Receive payment, Add price |
| Manage users and roles | Financial analytics (ops panel) + price admin |
