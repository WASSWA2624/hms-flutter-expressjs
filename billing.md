# Billing — complete screen blueprint

Source of truth for the **Billing** workspace. Mirror **Human resources** (`/hr`): one gated page, short desk tabs, `AppListTable` chrome, row → detail dialog.

**Billing is the only cashier desk.** Clinical modules post charges here; issue, collect, claims, approvals, and prices live here. No parallel billing UIs.

**Accounts is a separate module/screen** (`/accounts`, see `accounts.md`). Patient ledgers, general ledger, chart of accounts, journals, and books live there. Billing may deep-link to Accounts (e.g. patient ledger); it must not absorb Accounts UI.

**Reporting & analytics** owns period totals and financial KPIs. Billing does not host an Analytics tab.

| | |
|---|---|
| **Nav / title** | Billing |
| **Route** | `/billing` |
| **Module** | `billing-payments` (+ `insurance-claims` for Claims) |
| **Mirror** | `/hr` |
| **Sibling** | **Accounts** — separate screen; not a Billing tab |
| **Reports** | **Reporting & analytics** — not a Billing tab |

---

## UX principles (non-negotiable)

1. **Informative short labels** — tab labels use **up to 2 words** so the strip stays scannable but clear. Tooltips carry a full descriptive sentence. Row Next / trailing buttons stay 1–2 words with tooltips.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next action → one modal → save**. Detail dialog is for review + secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside the detail dialog.
5. **Adaptability** — fewer tabs, shared table contract, shared detail shell. New charge sources plug into Open work / To issue without new screens. Ledger browse lives on Accounts; analytics on Reporting.

---

## 1. Screen shell

```
AppAccessGate
└── AsyncStateScaffold ("Billing")
    └── ResponsivePage (dataHeavy, scrollable: false)
        └── Column
            ├── AppTabStrip  (≤2-word label + count; tooltip on hover/focus)
            └── Expanded → one table / panel
```

Rules:

1. No app-bar trailing actions.
2. First viewport = strip + one body. No KPI cards above the table.
3. Count tones: Open work = info · To issue / Collect due / Open claims / Need approval = warning · Collect due overdue subset uses danger badge on the **Overdue** filter chip, not a separate tab.
4. Fallback tab when unauthorized: **Open work**.
5. Snackbars for mutations; no sticky banner between strip and table.
6. Realtime + light poll on the active section.

### Search-bar order (every table)

```
[ Search ]  [ Filters ]  [ Table settings ]  [ Export ]  [ trailing — only where owned ]
```

---

## 2. Tabs (≤2-word labels + tooltips)

`BillingDeskSection` · URL `/billing?section=<slug>` (alias `?tab=`).

| # | Label | Tooltip | Enum | `?section=` | Body | Count |
|---|---|---|---|---|---|---|
| 1 | **Open work** | All billing items that still need action across issue, collect, claims, and approvals | `work` | `work` | Work queue | Open work |
| 2 | **To issue** | Draft invoices ready to issue to the patient or payer | `issue` | `issue` | Work queue | Drafts |
| 3 | **Collect due** | Open balances due for payment, including overdue | `collect` | `collect` | Work queue | Open balances |
| 4 | **Open claims** | Insurance claims and pre-authorizations awaiting action | `claims` | `claims` | Work queue | Open claims |
| 5 | **Need approval** | Refunds, voids, and adjustments awaiting approval | `approvals` | `approvals` | Work queue | Pending |
| 6 | **Price book** | Service and item prices used when charging | `prices` | `prices` | CRUD table | Active |

**Aliases (compat):** `all` / `inbox` → work · `needs-issue` / `ready-to-issue` → issue · `awaiting-payment` / `pending-payment` / `overdue` → collect · `claims-pending` → claims · `approval-required` → approvals · `price-book` → prices · `patient-ledgers` / `ledgers` → deep-link `/accounts?section=ledgers` · `analytics` → deep-link Reporting & analytics.

### What was deliberately removed / merged

| Removed | Why | Where it lives now |
|---|---|---|
| **Inbox** label | Sounds like email; vague for a cashier desk | Renamed **Open work** (same cross-queue list) |
| **Ledgers** tab | Patient money browse is books domain | **Accounts** → **Patient ledgers** (`accounts.md`) |
| **Analytics** tab | Period totals belong with reporting | **Reporting & analytics** |
| **Payments** tab | Duplicated Collect due + invoice payment history | Payments list inside **invoice detail**; refund/reconcile from there or Collect due next action |
| **Overdue** tab | Same rows as Collect due with age | **Collect due** + Overdue status/age filter (danger chip) |
| Close shift/day on every tab | Duplicate chrome | **Collect due** only |
| Quick charge on many tabs | Duplicate entry points | **Open work** only |
| Receive payment trailing on many tabs | Duplicate of row Pay | Row **Pay** / detail **Pay** only |
| Labels longer than 2 words | Slow scanning | Cap at 2 words; put the rest in the tooltip |

---

## 3. Shared work-queue contract

Used by **Open work · To issue · Collect due · Open claims · Need approval**.

| Control | Spec |
|---|---|
| **Search** | ~350ms debounce. Hint: *Patient, invoice, encounter…* |
| **Filters** | Shared sheet. Groups: Patient · Invoice · Encounter · Source · Status · Issued date. **Collect due** adds **Overdue** (Yes/No) and Age. |
| **Status choices** | Only statuses that exist on that tab (no global dump). |
| **Table settings** | Persist `billing_<section>_v1` |
| **Export** | Current filtered rows |
| **Default columns** | ≤5. Pool below; extras via settings. |
| **Row click** | One shared **Detail** dialog (kind-aware body). |
| **Next action** | Single primary button. Denied → omit (per product prompt: no disabled “no access” chrome). |

### Column pool (short headers)

| ID | Header | Default on |
|---|---|---|
| `patient` | Patient | all queues |
| `invoice` | Invoice | Open work, To issue, Collect due, Open claims, Need approval |
| `encounter` | Encounter | To issue, Open claims (optional elsewhere) |
| `source` | Source | optional |
| `due` | Due | Open work, Collect due, Need approval |
| `status` | Status | all queues |
| `age` | Age | Collect due (optional) |
| `type` | Type | Need approval (request type) |
| `next` | Next | all queues when user can act |

---

## 4. Tab specs

### 4.1 Open work (`work`)

Cross-queue list for “what needs me next” (issue, pay, claim, approve, …). Not an email inbox.

| | |
|---|---|
| **Columns** | Patient · Invoice · Due · Status · Next |
| **Empty** | *No open work.* |
| **Trailing (owned here)** | **Charge** |
| **Next priority** | Approve → Issue → Pay → Submit claim → Settle claim → Auth → Refund → Adjust → Void → Send |
| **Row click** | Detail |

### 4.2 To issue (`issue`)

Drafts only.

| | |
|---|---|
| **Columns** | Patient · Invoice · Encounter · Status · Next |
| **Empty** | *No drafts to issue.* |
| **Trailing** | **Issue all** (selection or page, write) |
| **Next** | **Issue** |
| **Row click** | Detail (secondary: Adjust, Void, Send, Ledger → Accounts, Print) |

### 4.3 Collect due (`collect`)

Open balances. Overdue is a **filter**, not a tab.

| | |
|---|---|
| **Columns** | Patient · Invoice · Due · Status · Next |
| **Empty** | *No balances due.* |
| **Trailing (owned here)** | **Close shift** · **Close day** |
| **Filters** | + Overdue chip (danger count) · Age |
| **Next** | **Pay** |
| **Deep link** | `?section=collect&action=pay&id=` → open Pay modal |
| **Row click** | Detail (secondary: Refund, Adjust, Void, Send, Ledger → Accounts, Print) |

### 4.4 Open claims (`claims`)

| | |
|---|---|
| **Gate** | `insurance-claims` |
| **Columns** | Patient · Invoice · Encounter · Status · Next |
| **Optional** | Insurer · Scheme · Patient share · Insurer share |
| **Empty** | *No open claims.* |
| **Trailing** | none |
| **Next** | **Submit** · **Settle** · **Auth** (by row kind) |
| **Row click** | Detail |

### 4.5 Need approval (`approvals`)

| | |
|---|---|
| **Columns** | Patient · Invoice · Due · Status · Next |
| **Optional** | Type · By · Reason |
| **Empty** | *No pending approvals.* |
| **Trailing** | none |
| **Next** | **Approve** (Reject only in Detail) |
| **Row click** | Detail |

### 4.6 Price book (`prices`)

| | |
|---|---|
| **Columns** | Item · Mode · Price · Status · Actions |
| **Optional** | Catalog · Scheme · Effective |
| **Empty** | *No prices match.* |
| **Trailing** | **Add** |
| **Row** | Edit / Deactivate · click opens edit dialog |

---

## 5. Trailing actions (one owner each)

| Button | Label | Owner tab only | Opens |
|---|---|---|---|
| Charge | *Charge* | Open work | Charge modal |
| Issue all | *Issue all* | To issue | Confirm → bulk issue |
| Close shift | *Close shift* | Collect due | Close shift modal |
| Close day | *Close day* | Collect due | Close day modal |
| Add | *Add* | Price book | Price create |

No other trailing buttons. Do not re-add Pay / Charge / Close on multiple tabs. Do not add Reports / Analytics trailing here.

---

## 6. Next actions (short labels)

| Label | Tooltip | Opens |
|---|---|---|
| **Issue** | Issue this draft invoice | Issue modal |
| **Pay** | Receive payment toward the balance due | Pay modal |
| **Refund** | Request a refund on this invoice | Refund modal |
| **Adjust** | Request an amount adjustment | Adjust modal |
| **Void** | Request to void this invoice | Void modal |
| **Send** | Send the invoice to the patient or payer | Send modal |
| **Approve** | Approve this pending request | Approve modal |
| **Submit** | Submit this claim to the insurer | Submit modal |
| **Settle** | Record the insurer’s claim response | Settle modal |
| **Auth** | Approve this pre-authorization | Auth modal |
| **Ledger** | Open the patient ledger in Accounts | Navigate `/accounts?section=ledgers&patientId=` |

One Next button per row. Everything else waits in Detail.

---

## 7. Flows (keep short)

### Happy paths (1 step)

| Intent | Flow |
|---|---|
| Issue draft | To issue → **Issue** → notes (optional) → save |
| Take payment | Collect due → **Pay** → amount/method → save |
| Approve | Need approval → **Approve** → save |
| Submit claim | Open claims → **Submit** → save |
| Open patient ledger | Detail / Next **Ledger** → Accounts **Patient ledgers** |
| Walk-in charge | Open work → **Charge** → save → lands on To issue |

### Detail path (only when needed)

Row click → **Detail** → secondary action (Refund / Adjust / Void / Reject / Deny / Print / Send / Ledger → Accounts).

Do **not** require Detail before Pay / Issue / Approve / Submit.

### Anti-patterns (forbidden)

- Tab A and Tab B showing the same queue with different names
- Close shift on every tab
- Pay trailing button + Pay next action + Pay in detail all competing on the same viewport
- Modal that only opens another modal before the user can finish
- Separate Payments tab that reprints invoice payment lines
- Separate Overdue tab that reprints Collect due rows
- Ledgers or Analytics tabs inside Billing
- Tab labels longer than 2 words (put detail in the tooltip)

---

## 8. Dialogs (shared, minimal)

One **Detail** shell; body switches by kind. Patient ledger UI is on **Accounts** (deep-link), not a Billing panel.

### 8.1 Detail

**Titles (short):** Invoice · Claim · Approval · Pre-auth · Item

**Always:** patient header · status · financial summary tiles · primary quick actions (same short labels as §6)

**Invoice sections (progressive):** Line items → Payments → Adjustments (collapsed/empty omitted)

**Actions shown only if capable:** Issue · Pay · Refund · Adjust · Void · Send · Approve · Reject · Submit · Settle · Auth · Deny · Clearance · Ledger (→ Accounts) · Print · Download

### 8.2 Pay

Fields: Amount · Method · Reference · Payer · Receipt toggle. Context line: Due + shares. Primary: **Pay**.

### 8.3 Issue / Send / Submit / Approve / Auth

Optional notes (Send adds email). Primary = short verb.

### 8.4 Refund / Adjust / Void / Reject / Deny / Settle

Only required fields (amount/reason/status). No extra wizard steps.

### 8.5 Close shift / Close day

Shift: Expected · Actual · Notes · Submit for approval. Day: Notes · Submit for approval.

### 8.6 Charge

Patient · Item · Qty · Price (book-resolved) · Mode · Notes. Primary: **Charge**. Creates draft → To issue tab.

### 8.7 Price Add/Edit

Item · Mode · Price · Scheme · Effective · Active. Primary: **Save**.

### 8.8 Clearance

One confirm: *Charges settled. Clear this encounter?* Primary: **Clear**.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route | `billing:read` ∪ `billing:write` ∩ `billing-payments` |
| Open claims tab | + `insurance-claims` |
| Write (Issue/Pay/Refund/Adjust/Void/Send/Close/Charge) | `billing:write` |
| Approve / Reject | `billing:write` ∩ `financial:approve` |
| Claim mutations | `billing:write` ∩ `insurance-claims` |
| Price book write | pricing/admin write |
| Ledger link | Accounts route gates (`accounts:read` ∩ `facility-accounts`); omit if unauthorized |

Hide unauthorized tabs and actions. Do not render disabled “no access” controls.

---

## 10. Deep links

| Query | Effect |
|---|---|
| `section` / `tab` | Desk section |
| `queue` | Legacy queue → mapped section |
| `search` | Prefill search |
| `id` | Open Detail after load |
| `patientId` | Prefer navigate `/accounts?section=ledgers&patientId=` (compat redirect) |
| `action=pay` | Open Pay on Collect due |

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

**Billing owns:** invoices, charge events, payments, refunds, adjustments, approvals, claims/pre-auth, price book — via Billing APIs. Clinical UIs deep-link here; they do not reimplement cashier flows.

**Accounts owns (separate screen):** patient ledgers, general ledger, chart of accounts, journals, period close/books, facility accounting views. Spec lives in `accounts.md`.

**Reporting & analytics owns:** period totals, cashier/facility financial KPIs and reports. Billing must not host an Analytics tab.

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
  billing_quick_charge_dialog.dart     # Charge
  billing_price_book_panel.dart
  billing_workspace_table_support.dart
```

No `billing_payments_panel` tab. Payment rows stay inside Detail.  
No `billing_ledgers_panel` or `billing_financial_analytics_panel`. Ledger → Accounts; analytics → Reporting.

---

## 14. Acceptance

- [ ] Six tabs with ≤2-word labels: Open work · To issue · Collect due · Open claims · Need approval · Price book
- [ ] Every tab has a descriptive tooltip (full sentence)
- [ ] No Inbox label; no Ledgers tab; no Analytics tab; no Payments tab; no Overdue tab
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Pay / Issue / Approve / Submit
- [ ] Ledger action deep-links to Accounts Patient ledgers
- [ ] Default columns ≤5; filters status lists are tab-scoped
- [ ] Unauthorized tabs/actions absent
- [ ] Chrome and mutate/refresh flow match `/hr`

---

## 15. Out of scope

| Item | Home |
|---|---|
| SaaS subscriptions | `/subscriptions` |
| **Accounts** (patient ledgers, GL, journals, chart of accounts, books) | Separate **Accounts** screen — `accounts.md` / `/accounts` |
| Clinical ordering | Clinical modules → deep-link Billing |
| Period analytics / heavy reporting | **Reporting & analytics** |

Do not place Accounts or Reporting tabs inside Billing. Optional future handoff: Billing posts settled totals to Accounts; Accounts never becomes a Billing desk section.

---

## 16. HR → Billing

| HR | Billing |
|---|---|
| Human resources | Billing |
| Staff members | *(patient ledgers → Accounts)* |
| Positions | Price book |
| Work queues | Open work / To issue / Collect due / Open claims / Need approval |
| Staff detail | Detail (+ Ledger → Accounts) |
| Trailing create on one tab | Charge on Open work; Add on Price book; Close on Collect due |
