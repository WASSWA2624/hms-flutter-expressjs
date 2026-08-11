# Accounts — complete screen blueprint

Source of truth for the **Accounts** workspace. Mirror **Human resources** (`/hr`) and **Billing** (`/billing`): one gated page, short desk tabs, `AppListTable` chrome, row → detail dialog.

**Accounts is the only books desk.** Patient ledgers, general ledger, chart of accounts, journals, period close, and facility accounting views live here. No parallel GL/journal/ledger UIs.

**Billing is a separate module/screen** (`/billing`, see `billing.md`). Accounts does not implement invoices, cashier collect, claims, or price book. Billing may deep-link here (patient ledger, settled summaries); Accounts must not absorb Billing UI.

**Reporting & analytics** owns period totals and financial KPIs. Accounts does not host an Analytics tab.

| | |
|---|---|
| **Nav / title** | Accounts |
| **Route** | `/accounts` |
| **Module** | `facility-accounts` |
| **Mirror** | `/hr` · `/billing` |
| **Sibling** | **Billing** — separate cashier desk; not an Accounts tab |
| **Reports** | **Reporting & analytics** — not an Accounts tab |

---

## UX principles (non-negotiable)

1. **Informative short labels** — tab labels use **up to 2 words** so the strip stays scannable but clear. Tooltips carry a full descriptive sentence. Row Next / trailing buttons stay 1–2 words with tooltips.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next action → one modal → save**. Detail dialog is for review + secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside the detail dialog.
5. **Adaptability** — fewer tabs, shared table contract, shared detail shell, shared ledger dialogs. New posting sources (e.g. Billing handoff) plug into Open work / To post without new screens. Analytics stays on Reporting.

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
3. Count tones: Open work = info · To post / Need approval / Close books = warning · Close books overdue/open-period risk uses danger badge on the **Overdue** / **Open** filter chip, not a separate tab.
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

| # | Label | Tooltip | Enum | `?section=` | Body | Count |
|---|---|---|---|---|---|---|
| 1 | **Open work** | All accounting items that still need action across journals, approvals, and period tasks | `work` | `work` | Work queue | Open work |
| 2 | **To post** | Draft journal entries ready to post to the books | `journals` | `journals` | Work queue | Drafts |
| 3 | **Need approval** | Journal posts, voids, reversals, and period close awaiting approval | `approvals` | `approvals` | Work queue | Pending |
| 4 | **General ledger** | Facility account balances and activity by GL account | `gl` | `gl` | Account table | With activity |
| 5 | **Patient ledgers** | Patient invoiced, paid, and outstanding balances | `ledgers` | `ledgers` | Patient table | With balance |
| 6 | **Account chart** | Chart of accounts codes, types, and status | `chart` | `chart` | CRUD table | Active |
| 7 | **Close books** | Fiscal periods: open, review checklist, and close | `books` | `books` | Period table | Open periods |

**Aliases (compat):** `all` / `inbox` → work · `journal-entries` / `unposted` / `ready-to-post` → journals · `approval-required` → approvals · `general-ledger` / `ledger` → gl · `patient-ledgers` → ledgers · `chart-of-accounts` / `coa` → chart · `periods` / `period-close` / `close` → books · `analytics` → deep-link Reporting & analytics.

### What was deliberately removed / merged

| Removed | Why | Where it lives now |
|---|---|---|
| **Inbox** label | Sounds like email; vague for a books desk | Renamed **Open work** (same cross-queue list) |
| **Analytics** tab | Period totals belong with reporting | **Reporting & analytics** |
| One-word **GL** / **Ledgers** / **Chart** / **Books** | Too terse on the strip | **General ledger** · **Patient ledgers** · **Account chart** · **Close books** |
| **Postings** tab | Same rows as Open work / To post with source filter | **Open work** + Source filter (Billing handoff, Manual, Payroll, …) |
| **Trial balance** tab | Snapshot of General ledger | **General ledger** export · **Close books** checklist · Reporting |
| Patient / invoice cashier tabs | Cashier domain | **Billing** (`billing.md`) |
| Close period on every tab | Duplicate chrome | **Close books** only |
| New journal on many tabs | Duplicate entry points | **Open work** only (**Journal**) |
| Post trailing on many tabs | Duplicate of row Post | Row **Post** / detail **Post** only |
| Labels longer than 2 words | Slow scanning | Cap at 2 words; put the rest in the tooltip |

---

## 3. Shared work-queue contract

Used by **Open work · To post · Need approval**.

| Control | Spec |
|---|---|
| **Search** | ~350ms debounce. Hint: *Account, journal, reference…* |
| **Filters** | Shared sheet. Groups: Account · Journal · Source · Status · Period · Posted date. **Close books**-related age only on Close books. **Patient ledgers** uses patient filters (separate table contract below). |
| **Status choices** | Only statuses that exist on that tab (no global dump). |
| **Table settings** | Persist `accounts_<section>_v1` |
| **Export** | Current filtered rows |
| **Default columns** | ≤5. Pool below; extras via settings. |
| **Row click** | One shared **Detail** dialog (kind-aware body). |
| **Next action** | Single primary button. Denied → omit (per product prompt: no disabled “no access” chrome). |

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

Cross-queue list for “what needs me next.” Includes Billing handoffs as a **source**, not a separate desk. Not an email inbox.

| | |
|---|---|
| **Columns** | Journal · Source · Amount · Status · Next |
| **Empty** | *No open work.* |
| **Trailing (owned here)** | **Journal** |
| **Next priority** | Approve → Post → Reverse → Void → Close → Open GL · Open patient ledger |
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

Facility general ledger by account — not a second journal queue, not patient money.

| | |
|---|---|
| **Columns** | Account · Debit · Credit · Balance · Next |
| **Optional** | Type · Period · Updated |
| **Empty** | *No accounts match.* |
| **Trailing** | none (Journal lives on Open work; Post on To post/row) |
| **Next** | Activity → **GL** · else omit |
| **Row click** | **Account ledger** dialog (same widget as Detail → GL) |

### 4.5 Patient ledgers (`ledgers`)

Patient money browse — moved from Billing. Not a second invoice queue and not facility GL.

| | |
|---|---|
| **Columns** | Patient · Invoiced · Paid · Balance · Next |
| **Optional** | Clearance · Updated |
| **Empty** | *No patients match.* |
| **Trailing** | none (Charge / Pay stay on Billing) |
| **Next** | Balance → **Pay** (deep-link Billing Collect due) · else → **Ledger** |
| **Deep link** | `?section=ledgers&patientId=` → open patient ledger dialog |
| **Row click** | **Patient ledger** dialog (same widget as Detail → Ledger) |

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
| **Deep link** | `?section=books&action=close&id=` → open Close period modal |
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

No other trailing buttons. Do not re-add Post / Journal / Close on multiple tabs. Do not add Reports / Analytics trailing here.

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
| **Pay** | Receive payment in Billing Collect due | Navigate `/billing?section=collect&action=pay&patientId=` |
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
| Take payment from balance | Patient ledgers → **Pay** → Billing Collect due pay modal |
| Manual journal | Open work → **Journal** → save → lands on To post |
| Close books | Close books → **Close** → notes → submit for approval |
| Billing handoff | Open work (Source=Billing) → **Post** or **Approve** |

### Detail path (only when needed)

Row click → **Detail** → secondary action (Reverse / Void / Reject / Deny / Print / Send / GL / Ledger).

Do **not** require Detail before Post / Approve / Close.

### Anti-patterns (forbidden)

- Tab A and Tab B showing the same queue with different names
- Close period on every tab
- Post trailing button + Post next action + Post in detail all competing on the same viewport
- Modal that only opens another modal before the user can finish
- Separate Postings tab that reprints Open work / To post
- Separate Trial balance tab that reprints General ledger
- Analytics tab inside Accounts
- Patient invoice / Collect due / Open claims / Price book tabs inside Accounts
- Absorbing Billing cashier flows into Accounts (Pay is a deep-link only)
- Tab labels longer than 2 words (put detail in the tooltip)

---

## 8. Dialogs (shared, minimal)

One **Detail** shell; body switches by kind. One **Account ledger** dialog and one **Patient ledger** dialog, each reused where needed.

### 8.1 Detail

**Titles (short):** Journal · Approval · Period · Account · Patient · Entry

**Always:** header (journal/account/period/patient) · status · amount summary tiles · primary quick actions (same short labels as §6)

**Journal sections (progressive):** Lines → Attachments / source ref → Approvals (collapsed/empty omitted)

**Actions shown only if capable:** Post · Approve · Reject · Reverse · Void · Send · Close · Open · GL · Ledger · Pay (→ Billing) · Print · Download

### 8.2 Post / Send / Approve / Open

Optional notes (Send adds email/export target). Primary = short verb.

### 8.3 Reverse / Void / Reject / Deny

Only required fields (reason/status; Reverse may require period). No extra wizard steps.

### 8.4 Close period

Checklist context (unposted count · pending approvals) · Notes · Submit for approval. Primary: **Close**.

### 8.5 Open period

Label / dates · Notes. Primary: **Open**.

### 8.6 Account ledger (GL)

Summary (Debit · Credit · Balance) + entry list. Actions: **Journal** only when user can create — do not add Post here (Post stays on To post).

### 8.7 Patient ledger

Summary (Invoiced · Paid · Balance) + entry list. Actions: **Pay** (if balance) deep-links to Billing — not Charge (Charge stays on Billing Open work).

### 8.8 Journal create

Date · Period · Source · balanced lines (Account · Debit · Credit · Memo) · Notes. Primary: **Save**. Creates draft → To post tab.

### 8.9 Chart Add/Edit

Code · Name · Type · Parent · Currency · Effective · Active. Primary: **Save**.

### 8.10 Books detail

Period header · status · close checklist · link to unposted To post filter.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route | `accounts:read` ∪ `accounts:write` ∩ `facility-accounts` |
| Write (Journal/Post/Reverse/Void/Send/Open/Close) | `accounts:write` |
| Approve / Reject | `accounts:write` ∩ `financial:approve` |
| Account chart write | accounts/admin write |
| Patient ledgers read | `accounts:read` (patient ledger browse) |
| Pay deep-link | Billing gates (`billing:write` ∩ `billing-payments`); omit if unauthorized |

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

Copy: *Saved.* · *Submitted for approval.* · *Posted.* · document save/fail strings as today.

---

## 12. Domain ownership

**Accounts owns:** patient ledgers, chart of accounts, journal entries, general ledger, period open/close, facility books views, approval of GL mutations — via Accounts APIs. Other modules may deep-link or post summary journals here; they do not reimplement books flows.

**Billing owns (separate screen):** invoices, charge events, payments, refunds, adjustments, cashier approvals, claims/pre-auth, price book. Spec lives in `billing.md`. Accounts must not add invoice/collect/claims/prices tabs or recreate Billing flows (Pay is deep-link only).

**Reporting & analytics owns:** period totals and financial KPIs/reports. Accounts must not host an Analytics tab.

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
  accounts_gl_dialog.dart                # one Account ledger (GL)
  accounts_patient_ledger_dialog.dart    # one Patient ledger
  accounts_chart_panel.dart
  accounts_gl_panel.dart
  accounts_ledgers_panel.dart            # patient balances
  accounts_books_panel.dart
  accounts_workspace_table_support.dart
```

No `accounts_postings_panel` tab. Billing handoffs stay in Open work / To post with Source filter.  
No `accounts_financial_analytics_panel`. Analytics → Reporting.  
No cashier Collect due / To issue widgets here — those stay in Billing.

---

## 14. Acceptance

- [ ] Seven tabs with ≤2-word labels: Open work · To post · Need approval · General ledger · Patient ledgers · Account chart · Close books
- [ ] Every tab has a descriptive tooltip (full sentence)
- [ ] No Inbox label; no Analytics tab; no Postings tab; no Trial balance tab; no Billing cashier tabs
- [ ] Patient ledgers live here (not under Billing)
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Post / Approve / Close
- [ ] Account ledger and patient ledger dialogs are shared with Detail
- [ ] Default columns ≤5; filters status lists are tab-scoped
- [ ] Unauthorized tabs/actions absent
- [ ] Chrome and mutate/refresh flow match `/hr` and `/billing`
- [ ] Billing remains a sibling screen; no General ledger / Patient ledgers tabs inside Billing

---

## 15. Out of scope

| Item | Home |
|---|---|
| SaaS subscriptions | `/subscriptions` |
| **Billing** (invoices, collect, claims, prices) | Separate **Billing** screen — `billing.md` / `/billing` |
| Staff payroll bank send | **HR** payroll → may post summary to Accounts later |
| User profile “Account” settings | `/settings` · `/profile` |
| Period analytics / heavy reporting | **Reporting & analytics** |

Do not place Billing or Reporting tabs inside Accounts. Optional future handoff: Billing posts settled totals to Accounts; Accounts never becomes a Billing desk section.

---

## 16. HR / Billing → Accounts

| HR / Billing | Accounts |
|---|---|
| Human resources / Billing | Accounts |
| Staff members / Billing Ledgers (removed) | **Patient ledgers** · **General ledger** |
| Positions / Price book | Account chart |
| Work queues | Open work / To post / Need approval |
| Staff detail / Invoice detail | Detail + GL / Patient ledger |
| Trailing create on one tab | Journal on Open work; Add on Account chart; Open/Close on Close books |
| Collect due / Close shift (Billing) | Not in Accounts — Close books is period close only; Pay deep-links Billing |
