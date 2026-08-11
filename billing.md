# Billing module plan

## Goal

Build a facility **Billing** workspace for patient revenue operations: invoices, collections, insurance claims handoff, adjustments/approvals, and overdue follow-up.

Name it **Billing** in navigation and the app bar (route `/billing`). Mirror the **Human resources** workspace pattern: tabbed desk → searchable table per tab → row opens a details dialog with contextual actions.

---

## UX analogy (Human resources)

| HR pattern | Billing equivalent |
|---|---|
| Screen title **Human resources** | Screen title **Billing** |
| `AppTabStrip` desk sections | Billing desk tabs (queues / work lists) |
| Per-tab `AppListTable` | Same shared table chrome |
| Search → **Filter** → **Table settings** → **Export** → trailing actions | Identical search-bar action order |
| Row select → `AppDialog` detail + quick actions | Invoice / payment / claim / approval detail dialog |
| Permission-gated tabs and actions | Billing read/write/approve/claims permissions |
| Deep links `?section=` / `?id=` | Deep links `?queue=` / `?id=` / patient / invoice filters |

Shared building blocks (do not invent parallel chrome):

- `AppTabStrip` / `AppTabItem`
- `AppListTable` + column visibility controller + export dialog
- `AppSearchBar` advanced filters
- `showAppDialog` / `AppInfoTileGrid` / `AppQuickActions`
- `AsyncStateScaffold` + `ResponsivePage` + `AppAccessGate`

---

## Screen shell

```
Billing
└── AppTabStrip (permission-filtered tabs, with counts)
    └── Active tab
        └── AppListTable
            ├── Search bar
            │   ├── text search (debounced)
            │   ├── Filter (advanced)
            │   ├── Table settings (column visibility)
            │   ├── Export
            │   └── Tab-specific trailing actions
            └── Rows → click opens details dialog
```

Rules:

1. One composition: tabs + one table. No dashboard cards on the first viewport.
2. Tab counts use warning/danger tones for actionable backlog (overdue = danger).
3. Mutations refresh the active queue; avoid page-level error banners between strip and table.
4. Keep deep-linkable state: queue, search, filters, and optional auto-open (`?id=`, `?action=pay`).

---

## Tabs

Organize Billing as work queues (same mental model as HR leave / swap / payroll queues). Each tab is a filtered work list over the shared billing ledger—not a separate product.

| Tab | Purpose | Primary row entity |
|---|---|---|
| **All billing work items** | Cross-queue inbox for cashiers / billing clerks | Invoice / work item |
| **Ready to issue** | Draft or ready invoices waiting to be issued / sent | Draft invoice |
| **Awaiting payment** | Issued invoices with patient (or facility) balance due | Open invoice |
| **Claims pending** | Insurer share / claim / pre-auth work still open | Claim or insured invoice |
| **Approval required** | Discounts, voids, refunds, write-offs awaiting decision | Approval request |
| **Overdue** | Past-due balances needing collection follow-up | Overdue invoice |

Optional later desk sections (only if product needs entity directories beyond queues—same table/dialog pattern):

- **Payments** — settled receipts, reconciliation, shift/day close history
- **Price book** — catalogue rates / payment modes (admin)
- **Patient ledger** — browse by patient rather than invoice queue

---

## Table chrome (every tab)

Inside the search bar, left-to-right:

1. **Search** — patient name/number, invoice number, encounter, source module
2. **Filter** — status, billing status, date range, facility, payment mode, source module, clearance state
3. **Table settings** — show/hide/reorder columns; persist per tab (`billing_work_queue_<tab>_…`)
4. **Export** — CSV/XLSX of the visible/filtered set
5. **Trailing actions** — tab-specific create/bulk/ops buttons (permission-gated)

### Suggested columns (vary by tab)

Common: Patient, Invoice #, Encounter / source, Amount, Balance, Status, Due / aged, Next action

Tab emphasis:

- Ready to issue → draft age, charge source, issue readiness
- Awaiting payment → amount due, method hints, last reminder
- Claims pending → insurer, claim status, patient vs insurer share
- Approval required → approval type, requester, amount, reason
- Overdue → days overdue, contact, collection stage

### Trailing actions by tab

| Tab | Examples |
|---|---|
| All | Close shift, Close day, Quick charge (if permitted) |
| Ready to issue | Issue selected, Send invoice |
| Awaiting payment | Receive payment, Send reminder |
| Claims pending | Submit claim, Reconcile remittance |
| Approval required | (mostly row actions; optional bulk decide) |
| Overdue | Collection note, Send dunning / reminder |

Inline **Next action** on the row (HR-style) for the primary happy path (Issue, Pay, Approve, Submit claim, etc.).

---

## Row → details dialog

Clicking a row opens a details dialog (`AppDialog`), not a full page.

### Dialog content

- Patient header (name, number, demographics) with link to **patient ledger**
- Invoice / claim / approval summary tiles (status, totals, patient share, insurer share, due date, source module)
- Line items (services, drugs, stay charges) with coverage split when insured
- Payment history and refunds (when applicable)
- Approval / claim timeline (when applicable)
- Related encounter / admission / request links

### Dialog actions (permission-gated, contextual)

| Action | When it appears |
|---|---|
| **Issue** | Draft / ready invoice |
| **Send** | Issued invoice not yet delivered |
| **Receive payment** | Balance due |
| **View ledger** | Always (read) |
| **Request adjustment** | Open invoice (discount / correction) |
| **Request refund** | Paid / partially paid |
| **Request void** | Issued invoice needing void approval |
| **Approve / Reject** | Pending approval items |
| **Submit claim** | Insured share ready |
| **Reconcile claim** | Claim awaiting remittance |
| **Approve / Deny pre-auth** | Pre-authorization pending |
| **Print / Download** | Invoice document |

Primary actions sit in `AppQuickActions`; destructive / approval flows use confirm / mutation dialogs.

---

## Domain capabilities the module must cover

### 1. Charge capture → invoice

- Clinical modules post billable charge events into Billing (OPD, pharmacy, lab, admission, ICU, emergency, mortuary, etc.).
- Billing owns pricing resolution (price book, scheme offers, copay / insurer split).
- Cashiers issue invoices from drafts; issued invoices become collectible.

### 2. Collections

- Receive payment (cash, mobile money, card, bank, other configured methods).
- Partial payments and remaining balance.
- Receipt / invoice document print & download.
- Shift close and day close against the Billing ledger.

### 3. Insurance & claims

- Patient vs insurer share on line items.
- Pre-authorization approve/deny where required.
- Claim submit and remittance reconcile.
- Claims work stays visible in **Claims pending** until settled or written off via Billing approvals.

### 4. Adjustments, refunds, voids

- Request-only mutations that create **approval** work items when policy requires it.
- Approvers decide on **Approval required** tab / detail dialog.
- No silent parallel ledgers—every money change posts through Billing APIs.

### 5. Overdue / clearance

- Age open balances into **Overdue**.
- Clearance state for clinical discharge / release gates where Billing is a blocker.
- Collection follow-up actions without leaving the Billing desk.

### 6. Patient ledger

- From detail dialog (or later dedicated tab): chronological charges, invoices, payments, refunds, adjustments for one patient.

### 7. Analytics (secondary)

- Financial analytics panel / report entry (period totals, collections, outstanding)—not the primary first-viewport composition.

---

## Permissions

Mirror HR: gate the workspace, each tab, and each mutation.

| Capability | Typical permission |
|---|---|
| Open Billing | `billing:read` |
| Issue / pay / adjust request | `billing:write` |
| Approve / reject | `billing:approve` (or equivalent) |
| Claims submit / reconcile | `billing:claims` (or equivalent) |
| Close shift / day | close / reconcile permission |
| Price book admin | pricing / admin permission |

Hide tabs the user cannot see; disable or omit actions they cannot run.

---

## Data model (backend anchors)

Core entities Billing owns or orchestrates:

- `invoice` / `invoice_item`
- `billable_charge_event`
- `payment` / `refund`
- `billing_adjustment` / `billing_approval`
- `price_book_entry` / `pricing_rule`
- `coverage_plan` / `insurance_company` / `insurance_claim` / `pre_authorization`

Workspace APIs should support:

- List work items by queue + search/filters + pagination
- Load invoice/claim/approval detail
- Issue, send, receive payment, refund request, adjustment request, void request
- Approve / reject
- Claim submit / reconcile, pre-auth decide
- Patient ledger
- Invoice document
- Shift / day close
- Financial analytics summary

---

## Implementation shape (frontend)

Follow the same feature layout as HR:

```
features/billing/
  domain/entities/
  data/ (DTOs, repository)
  presentation/
    pages/billing_workspace_page.dart
    controllers/
    widgets/ (detail body, payment dialog, ledger dialog, form dialogs, table support)
    billing_access.dart
```

Reuse existing shared table/dialog widgets. Prefer extending `/billing` queues and detail actions over creating a second finance screen.

---

## Acceptance checklist

- [ ] Nav and title show **Billing**
- [ ] Workspace is tabbed; each visible tab is permission-filtered with counts
- [ ] Every tab uses `AppListTable` with search, filter, table settings, export, and tab actions
- [ ] Row click opens a details dialog with metadata + contextual quick actions
- [ ] Happy-path next action is available on the row and in the dialog
- [ ] Payments, issues, refunds, adjustments, voids, and claim decisions go through Billing APIs only
- [ ] Deep links can open a queue, filter set, and optionally a detail or pay flow
- [ ] Look-and-feel matches Human resources (strip + table + dialog), not a card dashboard

---

## Out of scope (separate modules)

- Tenant SaaS **Subscriptions** billing
- Full general ledger / accounting books (if introduced later as **Accounts**)
- Standalone **Claims** product surfaces beyond the Billing claims queue handoff
- Clinical order entry (charges originate in clinical modules; Billing settles them)
