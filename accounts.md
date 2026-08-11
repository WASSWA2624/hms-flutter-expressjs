# Accounts — complete screen blueprint

Source of truth for the **Accounts** workspace. Mirror **Human resources** (`/hr`) and **Billing** (`/billing`): one gated page, short desk tabs, `AppListTable` chrome, row → detail dialog.

**Accounts is the only books desk.** Patient ledgers, general ledger, chart of accounts, journals, period close, and facility accounting views live here. No parallel GL / journal / ledger UIs.

**Billing** (`/billing`, `billing.md`) owns the cashier desk (invoices, collect, claims, price book). Accounts may deep-link to Billing for Pay; it must not absorb Billing UI.

**Reporting & analytics** owns period totals and financial KPIs. Accounts does not host an Analytics tab.

| | |
|---|---|
| **Nav / title** | Accounts |
| **Route** | `/accounts` |
| **Module** | `facility-accounts` |
| **Mirror** | `/hr` · `/billing` |
| **Sibling** | **Billing** — not an Accounts tab |
| **Reports** | **Reporting & analytics** — not an Accounts tab |

---

## UX principles (non-negotiable)

1. **Informative short labels** — tab labels use **up to 2 words**. Tooltips carry a full descriptive sentence. Row Next and trailing buttons stay 1–2 words with tooltips.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next → one modal → save**. Detail is for review and secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside Detail.
5. **Adaptability** — fewer tabs, shared table contract, shared Detail shell, shared ledger dialogs. New posting sources (e.g. Billing handoff) plug into Open work / To post without new screens.

---

## 1. Screen shell

```
AppAccessGate
└── AsyncStateScaffold ("Accounts")
    └── ResponsivePage (dataHeavy, scrollable: false)
        └── Column
            ├── AppTabStrip  (≤2-word label + count; tooltip on hover/focus)
            └── Expanded → one table / panel
```

Rules:

1. No app-bar trailing actions.
2. First viewport = strip + one body. No KPI cards above the table.
3. Count tones: Open work = info · To post / Need approval / Close books = warning · open-period risk uses danger on the **Overdue** / **Open** filter chip (not a tab).
4. Fallback tab when unauthorized: **Open work**.
5. Snackbars for mutations; no sticky banner between strip and table.
6. Realtime + light poll on the active section.

### Search-bar order (every table)

```
[ Search ]  [ Filters ]  [ Table settings ]  [ Export ]  [ trailing — only where owned ]
```

---

## 2. Tabs (≤2-word labels + tooltips)

`AccountsDeskSection` · URL `/accounts?section=<slug>` (alias `?tab=`).  
Display labels may be two words; **`?section=` slugs stay stable** (do not rename slugs when labels change).

| # | Label | Tooltip | Enum | `?section=` | Body | Count |
|---|---|---|---|---|---|---|
| 1 | **Open work** | All accounting items that still need action across journals, approvals, and period tasks | `work` | `work` | Work queue | Open items |
| 2 | **To post** | Draft journal entries ready to post to the books | `journals` | `journals` | Work queue | Drafts |
| 3 | **Need approval** | Journal posts, voids, reversals, and period close awaiting approval | `approvals` | `approvals` | Work queue | Pending |
| 4 | **General ledger** | Facility account balances and activity by GL account | `gl` | `gl` | Account table | With activity |
| 5 | **Patient ledgers** | Patient invoiced, paid, and outstanding balances | `ledgers` | `ledgers` | Patient table | With balance |
| 6 | **Account chart** | Chart of accounts codes, types, and status | `chart` | `chart` | CRUD table | Active |
| 7 | **Close books** | Fiscal periods: open, review checklist, and close | `books` | `books` | Period table | Open periods |

**Aliases (compat):** `all` / `inbox` → `work` · `journal-entries` / `unposted` / `ready-to-post` → `journals` · `approval-required` → `approvals` · `general-ledger` / `ledger` → `gl` · `patient-ledgers` → `ledgers` · `chart-of-accounts` / `coa` → `chart` · `periods` / `period-close` / `close` → `books` · `analytics` → Reporting & analytics.

---

## 3. Shared work-queue contract

Used by **Open work · To post · Need approval**.

| Control | Spec |
|---|---|
| **Search** | ~350ms debounce. Hint: *Account, journal, reference…* |
| **Filters** | Shared sheet. Groups: Account · Journal · Source · Status · Period · Posted date. |
| **Status choices** | Only statuses that exist on that tab (no global dump). |
| **Table settings** | Persist `accounts_<section>_v1` |
| **Export** | Current filtered rows |
| **Default columns** | ≤5. Pool below; extras via settings. |
| **Row click** | Shared **Detail** dialog (kind-aware body). |
| **Next action** | Single primary button. Unauthorized → omit (no disabled “no access” chrome). |

**Patient ledgers** and **Close books** use the same search-bar chrome with tab-local filters (patient / clearance on Patient ledgers; open / overdue-close on Close books).

### Column pool (short headers)

| ID | Header | Default on |
|---|---|---|
| `account` | Account | General ledger, Account chart; optional on queues |
| `patient` | Patient | Patient ledgers |
| `journal` | Journal | Open work, To post, Need approval |
| `source` | Source | Open work (optional elsewhere) |
| `period` | Period | To post, Need approval, Close books |
| `amount` | Amount | Open work, To post, Need approval |
| `status` | Status | all queues, Account chart, Close books |
| `type` | Type | Need approval (request type); Account chart (account type) |
| `balance` | Balance | General ledger, Patient ledgers |
| `invoiced` | Invoiced | Patient ledgers |
| `paid` | Paid | Patient ledgers |
| `next` | Next | queues / Patient ledgers when user can act |

---

## 4. Tab specs

### 4.1 Open work (`work`)

Cross-queue list for items that still need action. Billing handoffs appear as **Source = Billing**, not as a separate tab.

| | |
|---|---|
| **Columns** | Journal · Source · Amount · Status · Next |
| **Empty** | *No open work.* |
| **Trailing (owned here)** | **Journal** |
| **Next priority** | Approve → Post → Reverse → Void → Close → GL → Ledger |
| **Row click** | Detail |

### 4.2 To post (`journals`)

Draft / unposted journals only.

| | |
|---|---|
| **Columns** | Journal · Period · Amount · Status · Next |
| **Empty** | *No drafts to post.* |
| **Trailing** | **Post all** (selection or page, write) |
| **Next** | **Post** |
| **Row click** | Detail (secondary: Reverse, Void, Send, GL, Print) |

### 4.3 Need approval (`approvals`)

| | |
|---|---|
| **Columns** | Journal · Amount · Status · Next |
| **Optional** | Type · By · Reason · Period |
| **Empty** | *No pending approvals.* |
| **Trailing** | none |
| **Next** | **Approve** (Reject only in Detail) |
| **Row click** | Detail |

### 4.4 General ledger (`gl`)

Facility GL by account — not a second journal queue, not patient money.

| | |
|---|---|
| **Columns** | Account · Debit · Credit · Balance · Next |
| **Optional** | Type · Period · Updated |
| **Empty** | *No accounts match.* |
| **Trailing** | none |
| **Next** | Activity → **GL** · else omit |
| **Row click** | **Account ledger** dialog (same as Detail → GL) |

### 4.5 Patient ledgers (`ledgers`)

Patient money browse — not an invoice queue and not facility GL. Charge and collect stay on Billing.

| | |
|---|---|
| **Columns** | Patient · Invoiced · Paid · Balance · Next |
| **Optional** | Clearance · Updated |
| **Empty** | *No patients match.* |
| **Trailing** | none |
| **Next** | Balance → **Pay** (→ Billing Collect due) · else → **Ledger** |
| **Deep link** | `?section=ledgers&patientId=` → patient ledger dialog |
| **Row click** | **Patient ledger** dialog (same as Detail → Ledger) |

### 4.6 Account chart (`chart`)

| | |
|---|---|
| **Columns** | Account · Type · Code · Status · Actions |
| **Optional** | Parent · Currency · Effective |
| **Empty** | *No accounts match.* |
| **Trailing** | **Add** |
| **Row** | Edit / Deactivate · click opens edit dialog |

### 4.7 Close books (`books`)

Fiscal periods and close — not a journal reprint.

| | |
|---|---|
| **Columns** | Period · Status · Opened · Closed · Next |
| **Optional** | Facility · By |
| **Empty** | *No periods match.* |
| **Trailing (owned here)** | **Open period** · **Close period** |
| **Filters** | + Open chip · Overdue close chip (danger count) |
| **Next** | Open → **Close** · Pending approval → **Approve** · else → **Books** |
| **Deep link** | `?section=books&action=close&id=` → Close period modal |
| **Row click** | Detail (checklist: unposted journals, trial snapshot, approvals) |

---

## 5. Trailing actions (one owner each)

| Button | Label | Owner tab only | Opens |
|---|---|---|---|
| Journal | *Journal* | Open work | Journal create modal |
| Post all | *Post all* | To post | Confirm → bulk post |
| Open period | *Open period* | Close books | Open period modal |
| Close period | *Close period* | Close books | Close period modal |
| Add | *Add* | Account chart | Account create |

No other trailing buttons. Do not re-add Post / Journal / Close on multiple tabs.

---

## 6. Next actions (short labels)

| Label | Tooltip | Opens |
|---|---|---|
| **Post** | Post this draft journal to the books | Post modal |
| **Approve** | Approve this pending accounting request | Approve modal |
| **Reverse** | Request a reversal of this posting | Reverse modal |
| **Void** | Request to void this journal | Void modal |
| **Close** | Close this fiscal period | Close period modal |
| **Open** | Open a new fiscal period | Open period modal |
| **Send** | Send or export this journal | Send modal |
| **GL** | Open the facility account ledger | Account ledger dialog |
| **Ledger** | Open the patient money ledger | Patient ledger dialog |
| **Pay** | Receive payment in Billing Collect due | `/billing?section=collect&action=pay&patientId=` |
| **Books** | Open period detail and close checklist | Books detail |

One Next button per row. Everything else waits in Detail.

---

## 7. Flows (keep short)

### Happy paths (1 step)

| Intent | Flow |
|---|---|
| Post draft | To post → **Post** → notes (optional) → save |
| Approve | Need approval → **Approve** → save |
| Open account activity | General ledger → row or **GL** |
| Open patient ledger | Patient ledgers → row or **Ledger** |
| Take payment from balance | Patient ledgers → **Pay** → Billing Collect due |
| Manual journal | Open work → **Journal** → save → lands on To post |
| Close period | Close books → **Close** → notes → submit for approval |
| Billing handoff | Open work (Source = Billing) → **Post** or **Approve** |

### Detail path (only when needed)

Row click → **Detail** → secondary action (Reverse / Void / Reject / Deny / Print / Send / GL / Ledger).

Do **not** require Detail before Post / Approve / Close.

### Anti-patterns (forbidden)

- Two tabs showing the same queue under different names
- Close period / Open period outside Close books
- Post as trailing + Next + Detail primary competing in one viewport
- Modal that only opens another modal before the user can finish
- Postings, Trial balance, Analytics, or Billing cashier tabs inside Accounts
- Absorbing Collect due / Charge into Accounts (Pay is deep-link only)
- Tab labels longer than 2 words (put detail in the tooltip)

---

## 8. Dialogs (shared, minimal)

One **Detail** shell; body switches by kind. One **Account ledger** dialog and one **Patient ledger** dialog, reused everywhere.

### 8.1 Detail

**Titles (short):** Journal · Approval · Period · Account · Patient · Entry

**Always:** header · status · amount summary tiles · primary quick actions (same labels as §6)

**Journal sections (progressive):** Lines → Attachments / source ref → Approvals (collapsed/empty omitted)

**Actions shown only if capable:** Post · Approve · Reject · Reverse · Void · Send · Close · Open · GL · Ledger · Pay (→ Billing) · Print · Download

### 8.2 Post / Send / Approve / Open

Optional notes (Send adds email / export target). Primary = short verb.

### 8.3 Reverse / Void / Reject / Deny

Only required fields (reason / status; Reverse may require period). No wizard steps.

### 8.4 Close period

Checklist context (unposted count · pending approvals) · Notes · Submit for approval. Primary: **Close**.

### 8.5 Open period

Label / dates · Notes. Primary: **Open**.

### 8.6 Account ledger (GL)

Summary (Debit · Credit · Balance) + entry list. Actions: **Journal** when user can create — not Post (Post stays on To post).

### 8.7 Patient ledger

Summary (Invoiced · Paid · Balance) + entry list. Actions: **Pay** (if balance) → Billing — not Charge (Charge stays on Billing Open work).

### 8.8 Journal create

Date · Period · Source · balanced lines (Account · Debit · Credit · Memo) · Notes. Primary: **Save**. Creates draft → To post.

### 8.9 Chart Add/Edit

Code · Name · Type · Parent · Currency · Effective · Active. Primary: **Save**.

### 8.10 Books detail

Period header · status · close checklist · link to unposted To post filter.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route | (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts` |
| Write (Journal / Post / Reverse / Void / Send / Open / Close) | `accounts:write` |
| Approve / Reject | `accounts:write` ∩ `financial:approve` |
| Account chart write | accounts / admin write |
| Patient ledgers read | `accounts:read` |
| Pay deep-link | (`billing:write`) ∩ `billing-payments`; omit if unauthorized |

Hide unauthorized tabs and actions. Do not render disabled “no access” controls.

---

## 10. Deep links

| Query | Effect |
|---|---|
| `section` / `tab` | Desk section |
| `queue` | Legacy queue → mapped section |
| `search` | Prefill search |
| `id` | Open Detail after load |
| `accountId` | Open Account ledger or General ledger filter |
| `patientId` | Open Patient ledger or Patient ledgers filter |
| `periodId` | Open Books detail or Close books filter |
| `source` | Prefill Source filter (e.g. `billing`) |
| `action=post` | Open Post on To post |
| `action=close` | Open Close on Close books |

URL write: `/accounts?section=<slug>`.

---

## 11. Controller flow

```
load workspace → applySection / search / filters / page
mutate (one call) → snackbar → refresh active section + open detail if still needed
realtime while idle
```

Copy: *Saved.* · *Submitted for approval.* · *Posted.* · standard save / fail strings.

---

## 12. Domain ownership

| Owner | Owns |
|---|---|
| **Accounts** | Patient ledgers, chart of accounts, journals, general ledger, period open / close, facility books views, GL approvals |
| **Billing** | Invoices, charge events, payments, refunds, adjustments, cashier approvals, claims / pre-auth, price book |
| **Reporting & analytics** | Period totals, financial KPIs, heavy reports |

Other modules may deep-link or post summary journals here; they do not reimplement books flows. Optional later: Billing posts settled totals as journal drafts (Source = Billing) — Billing never becomes an Accounts tab.

---

## 13. Implementation map

```
presentation/pages/accounts_workspace_page.dart
presentation/accounts_access.dart
controllers/accounts_workspace_controller.dart
widgets/
  accounts_detail_widgets.dart           # one Detail shell
  accounts_form_dialogs.dart             # Post / Send / Reverse / Void / Approve / Open / Close / …
  accounts_journal_dialog.dart           # Journal create
  accounts_gl_dialog.dart                # Account ledger (GL)
  accounts_patient_ledger_dialog.dart    # Patient ledger
  accounts_chart_panel.dart
  accounts_gl_panel.dart
  accounts_ledgers_panel.dart            # patient balances
  accounts_books_panel.dart
  accounts_workspace_table_support.dart
```

Billing handoffs stay in Open work / To post via Source. No analytics panel. No cashier Collect due / Charge widgets here.

---

## 14. Acceptance

- [ ] Seven tabs: Open work · To post · Need approval · General ledger · Patient ledgers · Account chart · Close books
- [ ] Every tab has a ≤2-word label and a full-sentence tooltip
- [ ] Patient ledgers live here (not under Billing)
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Post / Approve / Close
- [ ] Account ledger and patient ledger dialogs are shared with Detail
- [ ] Default columns ≤5; status filters are tab-scoped
- [ ] Unauthorized tabs / actions are absent
- [ ] Chrome and mutate / refresh flow match `/hr` and `/billing`
- [ ] No Billing cashier tabs and no Analytics tab inside Accounts

---

## 15. Out of scope

| Item | Home |
|---|---|
| SaaS subscriptions | `/subscriptions` |
| Invoices, collect, claims, prices | `/billing` — `billing.md` |
| Staff payroll bank send | HR payroll → may post summary to Accounts later |
| User profile “Account” settings | `/settings` · `/profile` |
| Period analytics / heavy reporting | Reporting & analytics |

---

## 16. HR / Billing → Accounts chrome map

| HR / Billing | Accounts |
|---|---|
| Human resources / Billing | Accounts |
| Staff directory / patient money browse | Patient ledgers |
| Positions / Price book | Account chart |
| Work queues | Open work / To post / Need approval |
| Staff / invoice detail | Detail + GL / Patient ledger |
| Trailing create on one tab | Journal on Open work; Add on Account chart; Open / Close on Close books |
| Collect due / Close shift | Stay on Billing; Pay deep-links from Patient ledgers |
