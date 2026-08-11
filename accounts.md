# Accounts — complete screen blueprint

Source of truth for the **Accounts** workspace. Mirror **Human resources** (`/hr`) and **Billing** (`/billing`): one gated page, short desk tabs, `AppListTable` chrome, row → detail dialog.

**Accounts is the only facility books desk.** General ledger, chart of accounts, journals, period close, and facility accounting views live here. No parallel GL/journal UIs.

**Billing is a separate module/screen** (`/billing`, see `billing.md`). Accounts does not implement invoices, cashier collect, claims, patient ledgers, or price book. Billing may deep-link or post settled summaries here later; Accounts must not absorb Billing UI.

| | |
|---|---|
| **Nav / title** | Accounts |
| **Route** | `/accounts` |
| **Module** | `facility-accounts` |
| **Mirror** | `/hr` · `/billing` |
| **Sibling** | **Billing** — separate cashier desk; not an Accounts tab |

---

## UX principles (non-negotiable)

1. **Short labels** — tab and button text is 1–2 words; tooltips carry the longer explanation.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next action → one modal → save**. Detail dialog is for review + secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside the detail dialog.
5. **Adaptability** — fewer tabs, shared table contract, shared detail shell, shared account ledger dialog. New posting sources (e.g. Billing handoff) plug into Inbox/Journals without new screens.

---

## 1. Screen shell

```
AppAccessGate
└── AsyncStateScaffold ("Accounts")
    └── ResponsivePage (dataHeavy, scrollable: false)
        └── Column
            ├── AppTabStrip  (short label + count)
            └── Expanded → one table / panel
```

Rules:

1. No app-bar trailing actions.
2. First viewport = strip + one body. No KPI cards above the table.
3. Count tones: Inbox = info · Journals/Approvals/Books = warning · Books overdue/open-period risk uses danger badge on the **Overdue** / **Open** filter chip, not a separate tab.
4. Fallback tab when unauthorized: **Inbox**.
5. Snackbars for mutations; no sticky banner between strip and table.
6. Realtime + light poll on the active section.

### Search-bar order (every table)

```
[ Search ]  [ Filters ]  [ Table settings ]  [ Export ]  [ trailing — only where owned ]
```

---

## 2. Tabs (short labels)

`AccountsDeskSection` · URL `/accounts?section=<slug>` (alias `?tab=`).

| # | Label | Tooltip | Enum | `?section=` | Body | Count |
|---|---|---|---|---|---|---|
| 1 | **Inbox** | All open accounting work | `inbox` | `inbox` | Work queue | Open work |
| 2 | **Journals** | Drafts ready to post | `journals` | `journals` | Work queue | Drafts |
| 3 | **Approvals** | Post, void, reverse, close | `approvals` | `approvals` | Work queue | Pending |
| 4 | **Ledger** | GL balances by account | `ledger` | `ledger` | Account table | With activity |
| 5 | **Chart** | Chart of accounts | `chart` | `chart` | CRUD table | Active |
| 6 | **Books** | Periods & close | `books` | `books` | Period table | Open periods |
| 7 | **Analytics** | Period totals | `analytics` | `analytics` | Panel | — |

**Aliases (compat):** `all` → inbox · `journal-entries` / `unposted` / `ready-to-post` → journals · `approval-required` → approvals · `general-ledger` / `gl` → ledger · `chart-of-accounts` / `coa` → chart · `periods` / `period-close` / `close` → books.

### What was deliberately removed / merged

| Removed | Why | Where it lives now |
|---|---|---|
| **Postings** tab | Same rows as Inbox/Journals with source filter | **Inbox** + Source filter (Billing handoff, Manual, Payroll, …) |
| **Trial balance** tab | Snapshot of Ledger | **Ledger** export / Analytics progressive · **Books** close checklist |
| Patient / invoice tabs | Cashier domain | **Billing** (`billing.md`) |
| Close period on every tab | Duplicate chrome | **Books** only |
| New journal on many tabs | Duplicate entry points | **Inbox** only (**Journal**) |
| Post trailing on many tabs | Duplicate of row Post | Row **Post** / detail **Post** only |
| Long tab names | Slow scanning | 1-word labels above |

---

## 3. Shared work-queue contract

Used by **Inbox · Journals · Approvals**.

| Control | Spec |
|---|---|
| **Search** | ~350ms debounce. Hint: *Account, journal, reference…* |
| **Filters** | Shared sheet. Groups: Account · Journal · Source · Status · Period · Posted date. **Books**-related age only on Books. |
| **Status choices** | Only statuses that exist on that tab (no global dump). |
| **Table settings** | Persist `accounts_<section>_v1` |
| **Export** | Current filtered rows |
| **Default columns** | ≤5. Pool below; extras via settings. |
| **Row click** | One shared **Detail** dialog (kind-aware body). |
| **Next action** | Single primary button. Denied → omit (per product prompt: no disabled “no access” chrome). |

### Column pool (short headers)

| ID | Header | Default on |
|---|---|---|
| `account` | Account | Ledger, Chart; optional on queues |
| `journal` | Journal | Inbox, Journals, Approvals |
| `source` | Source | Inbox (optional elsewhere) |
| `period` | Period | Journals, Approvals, Books |
| `amount` | Amount | Inbox, Journals, Approvals |
| `status` | Status | all queues, Chart, Books |
| `type` | Type | Approvals (request type); Chart (account type) |
| `balance` | Balance | Ledger |
| `next` | Next | all queues when user can act |

---

## 4. Tab specs

### 4.1 Inbox (`inbox`)

Cross-queue list for “what needs me next.” Includes Billing handoffs as a **source**, not a separate desk.

| | |
|---|---|
| **Columns** | Journal · Source · Amount · Status · Next |
| **Empty** | *Nothing in the inbox.* |
| **Trailing (owned here)** | **Journal** |
| **Next priority** | Approve → Post → Reverse → Void → Close → Open ledger |
| **Row click** | Detail |

### 4.2 Journals (`journals`)

Draft / unposted journals only.

| | |
|---|---|
| **Columns** | Journal · Period · Amount · Status · Next |
| **Empty** | *No drafts to post.* |
| **Trailing** | **Post all** (selection or page, write) |
| **Next** | **Post** |
| **Row click** | Detail (secondary: Reverse, Void, Send, Ledger, Print) |

### 4.3 Approvals (`approvals`)

| | |
|---|---|
| **Columns** | Journal · Amount · Status · Next |
| **Optional** | Type · By · Reason · Period |
| **Empty** | *No pending approvals.* |
| **Trailing** | none |
| **Next** | **Approve** (Reject only in Detail) |
| **Row click** | Detail |

### 4.4 Ledger (`ledger`)

GL browse by account — not a second journal queue.

| | |
|---|---|
| **Columns** | Account · Debit · Credit · Balance · Next |
| **Optional** | Type · Period · Updated |
| **Empty** | *No accounts match.* |
| **Trailing** | none (Journal lives on Inbox; Post on Journals/row) |
| **Next** | Activity → **Ledger** · else omit |
| **Row click** | **Account ledger** dialog (same widget as Detail → Ledger) |

### 4.5 Chart (`chart`)

| | |
|---|---|
| **Columns** | Account · Type · Code · Status · Actions |
| **Optional** | Parent · Currency · Effective |
| **Empty** | *No accounts match.* |
| **Trailing** | **Add** |
| **Row** | Edit / Deactivate · click opens edit dialog |

### 4.6 Books (`books`)

Fiscal periods and close — not a journal reprint.

| | |
|---|---|
| **Columns** | Period · Status · Opened · Closed · Next |
| **Optional** | Facility · By |
| **Empty** | *No periods match.* |
| **Trailing (owned here)** | **Open period** · **Close period** |
| **Filters** | + Open chip · Overdue close chip (danger count) |
| **Next** | Open → **Close** · Pending approval → **Approve** · else → **Books** |
| **Deep link** | `?section=books&action=close&id=` → open Close period modal |
| **Row click** | Detail (checklist: unposted journals, trial snapshot, approvals) |

### 4.7 Analytics (`analytics`)

| | |
|---|---|
| **Body** | Compact KPI + period switch (Day / Month / Year / Custom) |
| **KPIs** | Debits · Credits · Net · Open journals |
| **More** | Progressive: by source · trend · account mix |
| **Action** | **Reports** (leaves to reporting when needed) |
| **Empty** | *No activity for this period.* |

---

## 5. Trailing actions (one owner each)

| Button | Label | Owner tab only | Opens |
|---|---|---|---|
| Journal | *Journal* | Inbox | Journal create modal |
| Post all | *Post all* | Journals | Confirm → bulk post |
| Open period | *Open period* | Books | Open period modal |
| Close period | *Close period* | Books | Close period modal |
| Add | *Add* | Chart | Account create |
| Reports | *Reports* | Analytics | Reports module |

No other trailing buttons. Do not re-add Post / Journal / Close on multiple tabs.

---

## 6. Next actions (short labels)

| Label | Tooltip | Opens |
|---|---|---|
| **Post** | Post journal | Post modal |
| **Approve** | Approve request | Approve modal |
| **Reverse** | Request reversal | Reverse modal |
| **Void** | Request void | Void modal |
| **Close** | Close period | Close period modal |
| **Open** | Open period | Open period modal |
| **Send** | Send journal / export | Send modal |
| **Ledger** | Open account ledger | Account ledger dialog |
| **Books** | Open period detail | Books detail |

One Next button per row. Everything else waits in Detail.

---

## 7. Flows (keep short)

### Happy paths (1 step)

| Intent | Flow |
|---|---|
| Post draft | Journals → **Post** → notes (optional) → save |
| Approve | Approvals → **Approve** → save |
| Open account activity | Ledger → row or **Ledger** |
| Manual journal | Inbox → **Journal** → save → lands on Journals |
| Close books | Books → **Close** → notes → submit for approval |
| Billing handoff | Inbox (Source=Billing) → **Post** or **Approve** |

### Detail path (only when needed)

Row click → **Detail** → secondary action (Reverse / Void / Reject / Deny / Print / Send / Ledger).

Do **not** require Detail before Post / Approve / Close.

### Anti-patterns (forbidden)

- Tab A and Tab B showing the same queue with different names
- Close period on every tab
- Post trailing button + Post next action + Post in detail all competing on the same viewport
- Modal that only opens another modal before the user can finish
- Separate Postings tab that reprints Inbox/Journals
- Separate Trial balance tab that reprints Ledger
- Patient invoice / Pay / Collect / Claims tabs inside Accounts
- Absorbing Billing cashier flows into Accounts

---

## 8. Dialogs (shared, minimal)

One **Detail** shell; body switches by kind. One **Account ledger** dialog reused everywhere.

### 8.1 Detail

**Titles (short):** Journal · Approval · Period · Account · Entry

**Always:** header (journal/account/period) · status · amount summary tiles · primary quick actions (same short labels as §6)

**Journal sections (progressive):** Lines → Attachments / source ref → Approvals (collapsed/empty omitted)

**Actions shown only if capable:** Post · Approve · Reject · Reverse · Void · Send · Close · Open · Ledger · Print · Download

### 8.2 Post / Send / Approve / Open

Optional notes (Send adds email/export target). Primary = short verb.

### 8.3 Reverse / Void / Reject / Deny

Only required fields (reason/status; Reverse may require period). No extra wizard steps.

### 8.4 Close period

Checklist context (unposted count · pending approvals) · Notes · Submit for approval. Primary: **Close**.

### 8.5 Open period

Label / dates · Notes. Primary: **Open**.

### 8.6 Account ledger

Summary (Debit · Credit · Balance) + entry list. Actions: **Journal** only when user can create — do not add Post here (Post stays on Journals).

### 8.7 Journal create

Date · Period · Source · balanced lines (Account · Debit · Credit · Memo) · Notes. Primary: **Save**. Creates draft → Journals tab.

### 8.8 Chart Add/Edit

Code · Name · Type · Parent · Currency · Effective · Active. Primary: **Save**.

### 8.9 Books detail

Period header · status · close checklist · link to unposted Journals filter.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route | `accounts:read` ∪ `accounts:write` ∩ `facility-accounts` |
| Write (Journal/Post/Reverse/Void/Send/Open/Close) | `accounts:write` |
| Approve / Reject | `accounts:write` ∩ `financial:approve` |
| Chart write | accounts/admin write |
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
| `accountId` | Open Account ledger or Ledger filter |
| `periodId` | Open Books detail or Books filter |
| `source` | Prefill Source filter (e.g. `billing`) |
| `action=post` | Open Post on Journals |
| `action=close` | Open Close on Books |

URL write: `/accounts?section=<slug>`.

---

## 11. Controller flow

```
load workspace → applySection / search / filters / page
mutate (one call) → snackbar → refresh active section + open detail if still needed
realtime while idle
```

Copy: *Saved.* · *Submitted for approval.* · *Posted.* · document save/fail strings as today.

---

## 12. Domain ownership

**Accounts owns:** chart of accounts, journal entries, general ledger, period open/close, facility books views, facility accounting analytics, approval of GL mutations — via Accounts APIs. Other modules may deep-link or post summary journals here; they do not reimplement books flows.

**Billing owns (separate screen):** invoices, charge events, payments, refunds, adjustments, cashier approvals, claims/pre-auth, price book, patient ledgers, cashier analytics. Spec lives in `billing.md`. Accounts must not add invoice/collect/claims tabs or recreate Billing flows.

**Handoff (optional later):** Billing posts settled totals into Accounts as journal drafts (Source=Billing). Accounts posts/approves them; Billing never becomes an Accounts desk section.

---

## 13. Implementation map

```
presentation/pages/accounts_workspace_page.dart
presentation/accounts_access.dart
controllers/accounts_workspace_controller.dart
widgets/
  accounts_detail_widgets.dart           # one Detail shell
  accounts_form_dialogs.dart             # Post/Send/Reverse/Void/Approve/Open/Close/…
  accounts_journal_dialog.dart           # Journal create
  accounts_ledger_dialog.dart            # one Account ledger
  accounts_chart_panel.dart
  accounts_ledger_panel.dart
  accounts_books_panel.dart
  accounts_financial_analytics_panel.dart
  accounts_workspace_table_support.dart
```

No `accounts_postings_panel` tab. Billing handoffs stay in Inbox/Journals with Source filter.  
No patient payment widgets here — those stay in Billing.

---

## 14. Acceptance

- [ ] Seven tabs with short labels: Inbox · Journals · Approvals · Ledger · Chart · Books · Analytics
- [ ] No Postings tab; no Trial balance tab; no Billing cashier tabs
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Post / Approve / Close
- [ ] Account ledger dialog is shared (Ledger tab + Detail)
- [ ] Default columns ≤5; filters status lists are tab-scoped
- [ ] Unauthorized tabs/actions absent
- [ ] Chrome and mutate/refresh flow match `/hr` and `/billing`
- [ ] Billing remains a sibling screen; no GL tabs inside Billing

---

## 15. Out of scope

| Item | Home |
|---|---|
| SaaS subscriptions | `/subscriptions` |
| **Billing** (invoices, collect, claims, patient ledgers, prices) | Separate **Billing** screen — `billing.md` / `/billing` |
| Staff payroll bank send | **HR** payroll → may post summary to Accounts later |
| User profile “Account” settings | `/settings` · `/profile` |
| Heavy reporting | Analytics → **Reports** |

Do not place Billing tabs inside Accounts. Optional future handoff: Billing posts settled totals to Accounts; Accounts never becomes a Billing desk section.

---

## 16. HR / Billing → Accounts

| HR / Billing | Accounts |
|---|---|
| Human resources / Billing | Accounts |
| Staff members / Ledgers | Ledger |
| Positions / Prices | Chart |
| Work queues | Inbox / Journals / Approvals |
| Staff detail / Invoice detail | Detail + Account ledger |
| Trailing create on one tab | Journal on Inbox; Add on Chart; Open/Close on Books |
| Collect / Close shift (Billing) | Not in Accounts — Books close is period close only |
