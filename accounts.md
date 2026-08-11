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

1. **Short labels** — tab and button text is 1–2 words; tooltips carry the longer explanation.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next action → one modal → save**. Detail dialog is for review + secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside the detail dialog.
5. **Adaptability** — fewer tabs, shared table contract, shared detail shell, shared ledger dialogs. New posting sources (e.g. Billing handoff) plug into Work/Journals without new screens. Analytics stays on Reporting.

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
3. Count tones: Work = info · Journals/Approvals/Books = warning · Books overdue/open-period risk uses danger badge on the **Overdue** / **Open** filter chip, not a separate tab.
4. Fallback tab when unauthorized: **Work**.
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
| 1 | **Work** | Open accounting work across queues | `work` | `work` | Work queue | Open work |
| 2 | **Journals** | Drafts ready to post | `journals` | `journals` | Work queue | Drafts |
| 3 | **Approvals** | Post, void, reverse, close | `approvals` | `approvals` | Work queue | Pending |
| 4 | **GL** | General ledger by account | `gl` | `gl` | Account table | With activity |
| 5 | **Ledgers** | Patient balances | `ledgers` | `ledgers` | Patient table | With balance |
| 6 | **Chart** | Chart of accounts | `chart` | `chart` | CRUD table | Active |
| 7 | **Books** | Periods & close | `books` | `books` | Period table | Open periods |

**Aliases (compat):** `all` / `inbox` → work · `journal-entries` / `unposted` / `ready-to-post` → journals · `approval-required` → approvals · `general-ledger` / `ledger` → gl · `patient-ledgers` → ledgers · `chart-of-accounts` / `coa` → chart · `periods` / `period-close` / `close` → books · `analytics` → deep-link Reporting & analytics.

### What was deliberately removed / merged

| Removed | Why | Where it lives now |
|---|---|---|
| **Inbox** label | Sounds like email; vague for a books desk | Renamed **Work** (same cross-queue list) |
| **Analytics** tab | Period totals belong with reporting | **Reporting & analytics** |
| **Ledger** label alone | Collided with patient Ledgers | Renamed **GL** (facility account browse) |
| **Postings** tab | Same rows as Work/Journals with source filter | **Work** + Source filter (Billing handoff, Manual, Payroll, …) |
| **Trial balance** tab | Snapshot of GL | **GL** export · **Books** close checklist · Reporting |
| Patient / invoice cashier tabs | Cashier domain | **Billing** (`billing.md`) |
| Close period on every tab | Duplicate chrome | **Books** only |
| New journal on many tabs | Duplicate entry points | **Work** only (**Journal**) |
| Post trailing on many tabs | Duplicate of row Post | Row **Post** / detail **Post** only |
| Long tab names | Slow scanning | 1-word labels above |

---

## 3. Shared work-queue contract

Used by **Work · Journals · Approvals**.

| Control | Spec |
|---|---|
| **Search** | ~350ms debounce. Hint: *Account, journal, reference…* |
| **Filters** | Shared sheet. Groups: Account · Journal · Source · Status · Period · Posted date. **Books**-related age only on Books. **Ledgers** uses patient filters (separate table contract below). |
| **Status choices** | Only statuses that exist on that tab (no global dump). |
| **Table settings** | Persist `accounts_<section>_v1` |
| **Export** | Current filtered rows |
| **Default columns** | ≤5. Pool below; extras via settings. |
| **Row click** | One shared **Detail** dialog (kind-aware body). |
| **Next action** | Single primary button. Denied → omit (per product prompt: no disabled “no access” chrome). |

### Column pool (short headers)

| ID | Header | Default on |
|---|---|---|
| `account` | Account | GL, Chart; optional on queues |
| `patient` | Patient | Ledgers |
| `journal` | Journal | Work, Journals, Approvals |
| `source` | Source | Work (optional elsewhere) |
| `period` | Period | Journals, Approvals, Books |
| `amount` | Amount | Work, Journals, Approvals |
| `status` | Status | all queues, Chart, Books |
| `type` | Type | Approvals (request type); Chart (account type) |
| `balance` | Balance | GL, Ledgers |
| `invoiced` | Invoiced | Ledgers |
| `paid` | Paid | Ledgers |
| `next` | Next | queues / Ledgers when user can act |

---

## 4. Tab specs

### 4.1 Work (`work`)

Cross-queue list for “what needs me next.” Includes Billing handoffs as a **source**, not a separate desk. Not an email inbox.

| | |
|---|---|
| **Columns** | Journal · Source · Amount · Status · Next |
| **Empty** | *No open work.* |
| **Trailing (owned here)** | **Journal** |
| **Next priority** | Approve → Post → Reverse → Void → Close → Open GL · Open patient ledger |
| **Row click** | Detail |

### 4.2 Journals (`journals`)

Draft / unposted journals only.

| | |
|---|---|
| **Columns** | Journal · Period · Amount · Status · Next |
| **Empty** | *No drafts to post.* |
| **Trailing** | **Post all** (selection or page, write) |
| **Next** | **Post** |
| **Row click** | Detail (secondary: Reverse, Void, Send, GL, Print) |

### 4.3 Approvals (`approvals`)

| | |
|---|---|
| **Columns** | Journal · Amount · Status · Next |
| **Optional** | Type · By · Reason · Period |
| **Empty** | *No pending approvals.* |
| **Trailing** | none |
| **Next** | **Approve** (Reject only in Detail) |
| **Row click** | Detail |

### 4.4 GL (`gl`)

Facility general ledger by account — not a second journal queue, not patient money.

| | |
|---|---|
| **Columns** | Account · Debit · Credit · Balance · Next |
| **Optional** | Type · Period · Updated |
| **Empty** | *No accounts match.* |
| **Trailing** | none (Journal lives on Work; Post on Journals/row) |
| **Next** | Activity → **GL** · else omit |
| **Row click** | **Account ledger** dialog (same widget as Detail → GL) |

### 4.5 Ledgers (`ledgers`)

Patient money browse — moved from Billing. Not a second invoice queue and not facility GL.

| | |
|---|---|
| **Columns** | Patient · Invoiced · Paid · Balance · Next |
| **Optional** | Clearance · Updated |
| **Empty** | *No patients match.* |
| **Trailing** | none (Charge / Pay stay on Billing) |
| **Next** | Balance → **Pay** (deep-link Billing Collect) · else → **Ledger** |
| **Deep link** | `?section=ledgers&patientId=` → open patient ledger dialog |
| **Row click** | **Patient ledger** dialog (same widget as Detail → Ledger) |

### 4.6 Chart (`chart`)

| | |
|---|---|
| **Columns** | Account · Type · Code · Status · Actions |
| **Optional** | Parent · Currency · Effective |
| **Empty** | *No accounts match.* |
| **Trailing** | **Add** |
| **Row** | Edit / Deactivate · click opens edit dialog |

### 4.7 Books (`books`)

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
| Journal | *Journal* | Work | Journal create modal |
| Post all | *Post all* | Journals | Confirm → bulk post |
| Open period | *Open period* | Books | Open period modal |
| Close period | *Close period* | Books | Close period modal |
| Add | *Add* | Chart | Account create |

No other trailing buttons. Do not re-add Post / Journal / Close on multiple tabs. Do not add Reports / Analytics trailing here.

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
| **GL** | Open account ledger | Account ledger dialog |
| **Ledger** | Open patient ledger | Patient ledger dialog |
| **Pay** | Receive payment | Navigate `/billing?section=collect&action=pay&patientId=` |
| **Books** | Open period detail | Books detail |

One Next button per row. Everything else waits in Detail.

---

## 7. Flows (keep short)

### Happy paths (1 step)

| Intent | Flow |
|---|---|
| Post draft | Journals → **Post** → notes (optional) → save |
| Approve | Approvals → **Approve** → save |
| Open account activity | GL → row or **GL** |
| Open patient ledger | Ledgers → row or **Ledger** |
| Take payment from balance | Ledgers → **Pay** → Billing Collect pay modal |
| Manual journal | Work → **Journal** → save → lands on Journals |
| Close books | Books → **Close** → notes → submit for approval |
| Billing handoff | Work (Source=Billing) → **Post** or **Approve** |

### Detail path (only when needed)

Row click → **Detail** → secondary action (Reverse / Void / Reject / Deny / Print / Send / GL / Ledger).

Do **not** require Detail before Post / Approve / Close.

### Anti-patterns (forbidden)

- Tab A and Tab B showing the same queue with different names
- Close period on every tab
- Post trailing button + Post next action + Post in detail all competing on the same viewport
- Modal that only opens another modal before the user can finish
- Separate Postings tab that reprints Work/Journals
- Separate Trial balance tab that reprints GL
- Analytics tab inside Accounts
- Patient invoice / Collect / Claims / Prices tabs inside Accounts
- Absorbing Billing cashier flows into Accounts (Pay is a deep-link only)

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

Summary (Debit · Credit · Balance) + entry list. Actions: **Journal** only when user can create — do not add Post here (Post stays on Journals).

### 8.7 Patient ledger

Summary (Invoiced · Paid · Balance) + entry list. Actions: **Pay** (if balance) deep-links to Billing — not Charge (Charge stays on Billing Work).

### 8.8 Journal create

Date · Period · Source · balanced lines (Account · Debit · Credit · Memo) · Notes. Primary: **Save**. Creates draft → Journals tab.

### 8.9 Chart Add/Edit

Code · Name · Type · Parent · Currency · Effective · Active. Primary: **Save**.

### 8.10 Books detail

Period header · status · close checklist · link to unposted Journals filter.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route | `accounts:read` ∪ `accounts:write` ∩ `facility-accounts` |
| Write (Journal/Post/Reverse/Void/Send/Open/Close) | `accounts:write` |
| Approve / Reject | `accounts:write` ∩ `financial:approve` |
| Chart write | accounts/admin write |
| Ledgers read | `accounts:read` (patient ledger browse) |
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
| `accountId` | Open Account ledger or GL filter |
| `patientId` | Open Patient ledger or Ledgers filter |
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

No `accounts_postings_panel` tab. Billing handoffs stay in Work/Journals with Source filter.  
No `accounts_financial_analytics_panel`. Analytics → Reporting.  
No cashier Collect/Issue widgets here — those stay in Billing.

---

## 14. Acceptance

- [ ] Seven tabs with short labels: Work · Journals · Approvals · GL · Ledgers · Chart · Books
- [ ] No Inbox label; no Analytics tab; no Postings tab; no Trial balance tab; no Billing cashier tabs
- [ ] Patient Ledgers live here (not under Billing)
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Post / Approve / Close
- [ ] Account ledger and patient ledger dialogs are shared with Detail
- [ ] Default columns ≤5; filters status lists are tab-scoped
- [ ] Unauthorized tabs/actions absent
- [ ] Chrome and mutate/refresh flow match `/hr` and `/billing`
- [ ] Billing remains a sibling screen; no GL/Ledgers tabs inside Billing

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
| Staff members / Billing Ledgers (removed) | **Ledgers** (patients) · **GL** (facility) |
| Positions / Prices | Chart |
| Work queues | Work / Journals / Approvals |
| Staff detail / Invoice detail | Detail + GL / Patient ledger |
| Trailing create on one tab | Journal on Work; Add on Chart; Open/Close on Books |
| Collect / Close shift (Billing) | Not in Accounts — Books close is period close only; Pay deep-links Billing |
