# Billing — complete screen blueprint

Source of truth for the **Billing** workspace. Mirror **Human resources** (`/hr`): one gated page, short desk tabs, `AppListTable` chrome, row → detail dialog.

**Billing is the only cashier desk.** Clinical modules post charges here; issue, collect, claims, approvals, patient ledgers, and prices live here. No parallel billing UIs.

**Accounts is a separate module/screen** (`/accounts`, see `accounts.md`). Billing does not implement general ledger, chart of accounts, journals, or books. Billing may deep-link or post summaries to Accounts later; it must not absorb Accounts UI.

| | |
|---|---|
| **Nav / title** | Billing |
| **Route** | `/billing` |
| **Module** | `billing-payments` (+ `insurance-claims` for Claims) |
| **Mirror** | `/hr` |
| **Sibling** | **Accounts** — separate screen; not a Billing tab |

---

## UX principles (non-negotiable)

1. **Short labels** — tab and button text is 1–2 words; tooltips carry the longer explanation.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next action → one modal → save**. Detail dialog is for review + secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside the detail dialog.
5. **Adaptability** — fewer tabs, shared table contract, shared detail shell, shared ledger dialog. New charge sources plug into Inbox/Issue without new screens.

---

## 1. Screen shell

```
AppAccessGate
└── AsyncStateScaffold ("Billing")
    └── ResponsivePage (dataHeavy, scrollable: false)
        └── Column
            ├── AppTabStrip  (short label + count)
            └── Expanded → one table / panel
```

Rules:

1. No app-bar trailing actions.
2. First viewport = strip + one body. No KPI cards above the table.
3. Count tones: Inbox = info · Issue/Collect/Claims/Approvals = warning · Collect overdue subset uses danger badge on the **Overdue** filter chip, not a separate tab.
4. Fallback tab when unauthorized: **Inbox**.
5. Snackbars for mutations; no sticky banner between strip and table.
6. Realtime + light poll on the active section.

### Search-bar order (every table)

```
[ Search ]  [ Filters ]  [ Table settings ]  [ Export ]  [ trailing — only where owned ]
```

---

## 2. Tabs (short labels)

`BillingDeskSection` · URL `/billing?section=<slug>` (alias `?tab=`).

| # | Label | Tooltip | Enum | `?section=` | Body | Count |
|---|---|---|---|---|---|---|
| 1 | **Inbox** | All open billing work | `inbox` | `inbox` | Work queue | Open work |
| 2 | **Issue** | Drafts ready to issue | `issue` | `issue` | Work queue | Drafts |
| 3 | **Collect** | Balances due (incl. overdue) | `collect` | `collect` | Work queue | Open balances |
| 4 | **Claims** | Claims & pre-auth | `claims` | `claims` | Work queue | Open claims |
| 5 | **Approvals** | Refunds, voids, adjustments | `approvals` | `approvals` | Work queue | Pending |
| 6 | **Ledgers** | Patient balances | `ledgers` | `ledgers` | Patient table | With balance |
| 7 | **Prices** | Price book | `prices` | `prices` | CRUD table | Active |
| 8 | **Analytics** | Period totals | `analytics` | `analytics` | Panel | — |

**Aliases (compat):** `all` → inbox · `needs-issue` / `ready-to-issue` → issue · `awaiting-payment` / `pending-payment` / `overdue` → collect · `claims-pending` → claims · `approval-required` → approvals · `patient-ledgers` → ledgers · `price-book` → prices.

### What was deliberately removed / merged

| Removed | Why | Where it lives now |
|---|---|---|
| **Payments** tab | Duplicated Collect + invoice payment history | Payments list inside **invoice detail**; refund/reconcile from there or Collect next action |
| **Overdue** tab | Same rows as Collect with age | **Collect** + Overdue status/age filter (danger chip) |
| Close shift/day on every tab | Duplicate chrome | **Collect** only |
| Quick charge on many tabs | Duplicate entry points | **Inbox** only |
| Receive payment trailing on many tabs | Duplicate of row Pay | Row **Pay** / detail **Pay** only |
| Long tab names | Slow scanning | 1-word labels above |

---

## 3. Shared work-queue contract

Used by **Inbox · Issue · Collect · Claims · Approvals**.

| Control | Spec |
|---|---|
| **Search** | ~350ms debounce. Hint: *Patient, invoice, encounter…* |
| **Filters** | Shared sheet. Groups: Patient · Invoice · Encounter · Source · Status · Issued date. **Collect** adds **Overdue** (Yes/No) and Age. |
| **Status choices** | Only statuses that exist on that tab (no global dump). |
| **Table settings** | Persist `billing_<section>_v1` |
| **Export** | Current filtered rows |
| **Default columns** | ≤5. Pool below; extras via settings. |
| **Row click** | One shared **Detail** dialog (kind-aware body). |
| **Next action** | Single primary button. Denied → omit (per product prompt: no disabled “no access” chrome). |

### Column pool (short headers)

| ID | Header | Default on |
|---|---|---|
| `patient` | Patient | all queues, Ledgers |
| `invoice` | Invoice | Inbox, Issue, Collect, Claims, Approvals |
| `encounter` | Encounter | Issue, Claims (optional elsewhere) |
| `source` | Source | optional |
| `due` | Due | Inbox, Collect, Approvals |
| `status` | Status | all queues |
| `age` | Age | Collect (optional) |
| `type` | Type | Approvals (request type) |
| `next` | Next | all queues when user can act |

---

## 4. Tab specs

### 4.1 Inbox (`inbox`)

Cross-queue list for “what needs me next.”

| | |
|---|---|
| **Columns** | Patient · Invoice · Due · Status · Next |
| **Empty** | *Nothing in the inbox.* |
| **Trailing (owned here)** | **Charge** |
| **Next priority** | Approve → Issue → Pay → Submit claim → Settle claim → Auth → Refund → Adjust → Void → Send |
| **Row click** | Detail |

### 4.2 Issue (`issue`)

Drafts only.

| | |
|---|---|
| **Columns** | Patient · Invoice · Encounter · Status · Next |
| **Empty** | *No drafts to issue.* |
| **Trailing** | **Issue all** (selection or page, write) |
| **Next** | **Issue** |
| **Row click** | Detail (secondary: Adjust, Void, Send, Ledger, Print) |

### 4.3 Collect (`collect`)

Open balances. Overdue is a **filter**, not a tab.

| | |
|---|---|
| **Columns** | Patient · Invoice · Due · Status · Next |
| **Empty** | *No balances due.* |
| **Trailing (owned here)** | **Close shift** · **Close day** |
| **Filters** | + Overdue chip (danger count) · Age |
| **Next** | **Pay** |
| **Deep link** | `?section=collect&action=pay&id=` → open Pay modal |
| **Row click** | Detail (secondary: Refund, Adjust, Void, Send, Ledger, Print) |

### 4.4 Claims (`claims`)

| | |
|---|---|
| **Gate** | `insurance-claims` |
| **Columns** | Patient · Invoice · Encounter · Status · Next |
| **Optional** | Insurer · Scheme · Patient share · Insurer share |
| **Empty** | *No open claims.* |
| **Trailing** | none |
| **Next** | **Submit** · **Settle** · **Auth** (by row kind) |
| **Row click** | Detail |

### 4.5 Approvals (`approvals`)

| | |
|---|---|
| **Columns** | Patient · Invoice · Due · Status · Next |
| **Optional** | Type · By · Reason |
| **Empty** | *No pending approvals.* |
| **Trailing** | none |
| **Next** | **Approve** (Reject only in Detail) |
| **Row click** | Detail |

### 4.6 Ledgers (`ledgers`)

Patient money browse — not a second invoice queue.

| | |
|---|---|
| **Columns** | Patient · Invoiced · Paid · Balance · Next |
| **Optional** | Clearance · Updated |
| **Empty** | *No patients match.* |
| **Trailing** | none (Charge lives on Inbox; Pay on Collect/row) |
| **Next** | Balance → **Pay** · else → **Ledger** |
| **Row click** | **Ledger** dialog (same widget as Detail → Ledger) |

### 4.7 Prices (`prices`)

| | |
|---|---|
| **Columns** | Item · Mode · Price · Status · Actions |
| **Optional** | Catalog · Scheme · Effective |
| **Empty** | *No prices match.* |
| **Trailing** | **Add** |
| **Row** | Edit / Deactivate · click opens edit dialog |

### 4.8 Analytics (`analytics`)

| | |
|---|---|
| **Body** | Compact KPI + period switch (Day / Month / Year / Custom) |
| **KPIs** | Collected · Spent · Surplus · Open invoices |
| **More** | Progressive: by method · trend · mix |
| **Action** | **Reports** (leaves to reporting when needed) |
| **Empty** | *No activity for this period.* |

---

## 5. Trailing actions (one owner each)

| Button | Label | Owner tab only | Opens |
|---|---|---|---|
| Charge | *Charge* | Inbox | Charge modal |
| Issue all | *Issue all* | Issue | Confirm → bulk issue |
| Close shift | *Close shift* | Collect | Close shift modal |
| Close day | *Close day* | Collect | Close day modal |
| Add | *Add* | Prices | Price create |
| Reports | *Reports* | Analytics | Reports module |

No other trailing buttons. Do not re-add Pay / Charge / Close on multiple tabs.

---

## 6. Next actions (short labels)

| Label | Tooltip | Opens |
|---|---|---|
| **Issue** | Issue invoice | Issue modal |
| **Pay** | Receive payment | Pay modal |
| **Refund** | Request refund | Refund modal |
| **Adjust** | Request adjustment | Adjust modal |
| **Void** | Request void | Void modal |
| **Send** | Send invoice | Send modal |
| **Approve** | Approve request | Approve modal |
| **Submit** | Submit claim | Submit modal |
| **Settle** | Record insurer response | Settle modal |
| **Auth** | Approve authorization | Auth modal |
| **Ledger** | Open patient ledger | Ledger dialog |

One Next button per row. Everything else waits in Detail.

---

## 7. Flows (keep short)

### Happy paths (1 step)

| Intent | Flow |
|---|---|
| Issue draft | Issue tab → **Issue** → notes (optional) → save |
| Take payment | Collect → **Pay** → amount/method → save |
| Approve | Approvals → **Approve** → save |
| Submit claim | Claims → **Submit** → save |
| Open ledger | Ledgers → row or **Ledger** |
| Walk-in charge | Inbox → **Charge** → save → lands on Issue |

### Detail path (only when needed)

Row click → **Detail** → secondary action (Refund / Adjust / Void / Reject / Deny / Print / Send / Ledger).

Do **not** require Detail before Pay / Issue / Approve / Submit.

### Anti-patterns (forbidden)

- Tab A and Tab B showing the same queue with different names
- Close shift on every tab
- Pay trailing button + Pay next action + Pay in detail all competing on the same viewport
- Modal that only opens another modal before the user can finish
- Separate Payments tab that reprints invoice payment lines
- Separate Overdue tab that reprints Collect rows

---

## 8. Dialogs (shared, minimal)

One **Detail** shell; body switches by kind. One **Ledger** dialog reused everywhere.

### 8.1 Detail

**Titles (short):** Invoice · Claim · Approval · Pre-auth · Item

**Always:** patient header · status · financial summary tiles · primary quick actions (same short labels as §6)

**Invoice sections (progressive):** Line items → Payments → Adjustments (collapsed/empty omitted)

**Actions shown only if capable:** Issue · Pay · Refund · Adjust · Void · Send · Approve · Reject · Submit · Settle · Auth · Deny · Clearance · Ledger · Print · Download

### 8.2 Pay

Fields: Amount · Method · Reference · Payer · Receipt toggle. Context line: Due + shares. Primary: **Pay**.

### 8.3 Issue / Send / Submit / Approve / Auth

Optional notes (Send adds email). Primary = short verb.

### 8.4 Refund / Adjust / Void / Reject / Deny / Settle

Only required fields (amount/reason/status). No extra wizard steps.

### 8.5 Close shift / Close day

Shift: Expected · Actual · Notes · Submit for approval. Day: Notes · Submit for approval.

### 8.6 Ledger

Summary (Invoiced · Paid · Balance) + entry list. Actions: **Pay** (if balance) only — not Charge (Charge stays on Inbox).

### 8.7 Charge

Patient · Item · Qty · Price (book-resolved) · Mode · Notes. Primary: **Charge**. Creates draft → Issue tab.

### 8.8 Price Add/Edit

Item · Mode · Price · Scheme · Effective · Active. Primary: **Save**.

### 8.9 Clearance

One confirm: *Charges settled. Clear this encounter?* Primary: **Clear**.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route | `billing:read` ∪ `billing:write` ∩ `billing-payments` |
| Claims tab | + `insurance-claims` |
| Write (Issue/Pay/Refund/Adjust/Void/Send/Close/Charge) | `billing:write` |
| Approve / Reject | `billing:write` ∩ `financial:approve` |
| Claim mutations | `billing:write` ∩ `insurance-claims` |
| Prices write | pricing/admin write |
| Analytics / Reports | read; Reports needs `reports:read` |

Hide unauthorized tabs and actions. Do not render disabled “no access” controls.

---

## 10. Deep links

| Query | Effect |
|---|---|
| `section` / `tab` | Desk section |
| `queue` | Legacy queue → mapped section |
| `search` | Prefill search |
| `id` | Open Detail after load |
| `patientId` | Open Ledger or Ledgers filter |
| `action=pay` | Open Pay on Collect |

URL write: `/billing?section=<slug>`.

---

## 11. Controller flow

```
load workspace → applySection / search / filters / page
mutate (one call) → snackbar → refresh active section + open detail if still needed
realtime while idle
```

Copy: *Saved.* · *Submitted for approval.* · document save/fail strings as today.

---

## 12. Domain ownership

**Billing owns:** invoices, charge events, payments, refunds, adjustments, approvals, claims/pre-auth, price book, patient ledgers, cashier analytics — via Billing APIs. Clinical UIs deep-link here; they do not reimplement cashier flows.

**Accounts owns (separate screen):** general ledger, chart of accounts, journals, period close/books, facility accounting views. Spec lives in `accounts.md`. Billing must not add GL/journal tabs or recreate Accounts flows.

---

## 13. Implementation map

```
presentation/pages/billing_workspace_page.dart
presentation/billing_access.dart
controllers/billing_workspace_controller.dart
widgets/
  billing_detail_widgets.dart          # one Detail shell
  billing_receive_payment_dialog.dart  # Pay
  billing_form_dialogs.dart            # Issue/Send/Refund/Adjust/Void/Approve/…
  billing_ledger_dialog.dart           # one Ledger
  billing_quick_charge_dialog.dart     # Charge
  billing_price_book_panel.dart
  billing_ledgers_panel.dart
  billing_financial_analytics_panel.dart
  billing_workspace_table_support.dart
```

No `billing_payments_panel` tab. Payment rows stay inside Detail.

---

## 14. Acceptance

- [ ] Eight tabs with short labels: Inbox · Issue · Collect · Claims · Approvals · Ledgers · Prices · Analytics
- [ ] No Payments tab; no Overdue tab
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Pay / Issue / Approve / Submit
- [ ] Ledger dialog is shared (Ledgers tab + Detail)
- [ ] Default columns ≤5; filters status lists are tab-scoped
- [ ] Unauthorized tabs/actions absent
- [ ] Chrome and mutate/refresh flow match `/hr`

---

## 15. Out of scope

| Item | Home |
|---|---|
| SaaS subscriptions | `/subscriptions` |
| **Accounts** (GL, journals, chart of accounts, books) | Separate **Accounts** screen — `accounts.md` / `/accounts` |
| Clinical ordering | Clinical modules → deep-link Billing |
| Heavy reporting | Analytics → **Reports** |

Do not place Accounts tabs inside Billing. Optional future handoff: Billing posts settled totals to Accounts; Accounts never becomes a Billing desk section.

---

## 16. HR → Billing

| HR | Billing |
|---|---|
| Human resources | Billing |
| Staff members | Ledgers |
| Positions | Prices |
| Work queues | Inbox / Issue / Collect / Claims / Approvals |
| Staff detail | Detail + Ledger |
| Trailing create on one tab | Charge on Inbox; Add on Prices; Close on Collect |
