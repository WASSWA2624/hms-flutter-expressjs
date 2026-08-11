# Billing — complete screen blueprint

Source of truth for the **Billing** workspace. Mirror **Human resources** (`/hr`): one gated page, short desk tabs, `AppListTable` chrome, row → detail dialog.

**Billing is the only cashier desk.** Clinical modules post charges here. Issue, collect, claims, approvals, and prices live here. No parallel billing UIs.

**Accounts** (`/accounts`, `accounts.md`) owns patient ledgers and facility books. Billing may deep-link there; it must not absorb Accounts UI.

**Reporting & analytics** owns period totals and financial KPIs. Billing does not host an Analytics tab.

| | |
|---|---|
| **Nav / title** | Billing |
| **Route** | `/billing` |
| **Module** | `billing-payments` (+ `insurance-claims` for Open claims) |
| **Mirror** | `/hr` |
| **Sibling** | **Accounts** — not a Billing tab |
| **Reports** | **Reporting & analytics** — not a Billing tab |

---

## UX principles (non-negotiable)

1. **Informative short labels** — tab labels use **up to 2 words**. Tooltips carry a full descriptive sentence. Row Next and trailing buttons stay 1–2 words with tooltips.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next → one modal → save**. Detail is for review and secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside Detail.
5. **Adaptability** — fewer tabs, shared table contract, shared Detail shell. New charge sources plug into Open work / To issue without new screens.
6. **Human-readable IDs only** — never display raw UUIDs or internal primary keys in tables, Detail, dialogs, filters, snackbars, printouts, or URLs the user sees. Use `human_friendly_id`, invoice numbers, patient display names/MRNs, encounter codes, and catalog codes.
7. **Print = preview first** — every Print / receipt / download-print path opens the shared print-preview workspace with comprehensive section options before printing. Printed layout must be branded, well spaced, and visually clear (see §17).
8. **Similarity on create/update** — every create and update dialog runs similarity review before commit when near/exact matches exist (see §18).

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
3. Count tones: Open work = info · To issue / Collect due / Open claims / Need approval = warning · overdue subset uses danger on the **Overdue** filter chip (not a tab).
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
Display labels may be two words; **`?section=` slugs stay stable** (do not rename slugs when labels change).

| # | Label | Tooltip | Enum | `?section=` | Body | Count |
|---|---|---|---|---|---|---|
| 1 | **Open work** | All billing items that still need action across issue, collect, claims, and approvals | `work` | `work` | Work queue | Open items |
| 2 | **To issue** | Draft invoices ready to issue to the patient or payer | `issue` | `issue` | Work queue | Drafts |
| 3 | **Collect due** | Open balances due for payment, including overdue | `collect` | `collect` | Work queue | Open balances |
| 4 | **Open claims** | Insurance claims and pre-authorizations awaiting action | `claims` | `claims` | Work queue | Open claims |
| 5 | **Need approval** | Refunds, voids, and adjustments awaiting approval | `approvals` | `approvals` | Work queue | Pending |
| 6 | **Price book** | Service and item prices used when charging | `prices` | `prices` | CRUD table | Active |

**Aliases (compat):** `all` / `inbox` → `work` · `needs-issue` / `ready-to-issue` → `issue` · `awaiting-payment` / `pending-payment` / `overdue` → `collect` · `claims-pending` → `claims` · `approval-required` → `approvals` · `price-book` → `prices` · `patient-ledgers` / `ledgers` → `/accounts?section=ledgers` · `analytics` → Reporting & analytics.

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
| **Row click** | Shared **Detail** dialog (kind-aware body). |
| **Next action** | Single primary button. Unauthorized → omit (no disabled “no access” chrome). |

### Column pool (short headers)

| ID | Header | Default on |
|---|---|---|
| `patient` | Patient | all queues |
| `invoice` | Invoice | all queues |
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

Cross-queue list for items that still need action (issue, pay, claim, approve, …).

| | |
|---|---|
| **Columns** | Patient · Invoice · Due · Status · Next |
| **Empty** | *No open work.* |
| **Trailing (owned here)** | **Charge** |
| **Next priority** | Approve → Issue → Pay → Submit → Settle → Auth → Refund → Adjust → Void → Send |
| **Row click** | Detail |

### 4.2 To issue (`issue`)

Draft invoices only.

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
| **Deep link** | `?section=collect&action=pay&id=` → Pay modal |
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

No other trailing buttons. Do not re-add Pay / Charge / Close on multiple tabs.

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
| **Settle** | Record the insurer response | Settle modal |
| **Auth** | Approve this pre-authorization | Auth modal |
| **Ledger** | Open the patient ledger in Accounts | `/accounts?section=ledgers&patientId=` |

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

- Two tabs showing the same queue under different names
- Close shift / Close day outside Collect due
- Pay as trailing + Next + Detail primary competing in one viewport
- Modal that only opens another modal before the user can finish
- Payments, Overdue, Ledgers, or Analytics tabs inside Billing
- Tab labels longer than 2 words (put detail in the tooltip)

---

## 8. Dialogs (shared, minimal)

One **Detail** shell; body switches by kind. Patient ledger UI lives on **Accounts** (deep-link only).

### 8.1 Detail

**Titles (short):** Invoice · Claim · Approval · Pre-auth · Item

**Always:** patient header · status · financial summary tiles · primary quick actions (same labels as §6)

**Invoice sections (progressive):** Line items → Payments → Adjustments (collapsed/empty omitted)

**Actions shown only if capable:** Issue · Pay · Refund · Adjust · Void · Send · Approve · Reject · Submit · Settle · Auth · Deny · Clearance · Ledger (→ Accounts) · Print · Download

**Identifiers:** show invoice number, patient display name / MRN, encounter code — never UUIDs.

### 8.2 Pay

Fields: Amount · Method · Reference · Payer · Receipt toggle. Context: Due + shares. Primary: **Pay**.  
When Receipt is on (or user chooses Print after pay), open **Print preview** (§17) for the receipt — do not print silently.

### 8.3 Issue / Send / Submit / Approve / Auth

Optional notes (Send adds email). Primary = short verb.

### 8.4 Refund / Adjust / Void / Reject / Deny / Settle

Only required fields (amount / reason / status). No wizard steps. Adjust (amount update) runs similarity / near-duplicate review when an equivalent pending adjust already exists (§18).

### 8.5 Close shift / Close day

Shift: Expected · Actual · Notes · Submit for approval. Day: Notes · Submit for approval.

### 8.6 Charge

Patient · Item · Qty · Price (book-resolved) · Mode · Notes. Primary: **Charge**. Creates draft → To issue.  
**Before save:** run similarity check against near-duplicate open drafts / recent charges for the same patient · item · encounter (§18).

### 8.7 Price Add/Edit

Item · Mode · Price · Scheme · Effective · Active. Primary: **Save**.  
**Before save (create and update):** run similarity check on Item · Mode · Scheme · Effective against existing price-book rows (§18). Exact match blocks create; near match offers Select existing / Overwrite / Continue.

### 8.8 Clearance

One confirm: *Charges settled. Clear this encounter?* Primary: **Clear**.

### 8.9 Print preview

Opened from Detail **Print**, Pay receipt, Send→print, or any other print entry. Reuse `AppPrintPreviewWorkspace` / `AppReportSectionPicker` (mirror HR / clinical print). See §17.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route | (`billing:read` ∪ `billing:write`) ∩ `billing-payments` |
| Open claims tab | + `insurance-claims` |
| Write (Issue / Pay / Refund / Adjust / Void / Send / Close / Charge) | `billing:write` |
| Approve / Reject | `billing:write` ∩ `financial:approve` |
| Claim mutations | `billing:write` ∩ `insurance-claims` |
| Price book write | pricing / admin write |
| Ledger link | (`accounts:read`) ∩ `facility-accounts`; omit if unauthorized |

Hide unauthorized tabs and actions. Do not render disabled “no access” controls.

---

## 10. Deep links

| Query | Effect |
|---|---|
| `section` / `tab` | Desk section |
| `queue` | Legacy queue → mapped section |
| `search` | Prefill search |
| `id` | Open Detail after load |
| `patientId` | Redirect to `/accounts?section=ledgers&patientId=` |
| `action=pay` | Open Pay on Collect due (`id` = invoice) |

URL write: `/billing?section=<slug>`.

---

## 11. Controller flow

```
load workspace → applySection / search / filters / page
mutate (one call) → snackbar → refresh active section + open detail if still needed
realtime while idle
```

Copy: *Saved.* · *Submitted for approval.* · standard save / fail strings.

---

## 12. Domain ownership

| Owner | Owns |
|---|---|
| **Billing** | Invoices, charge events, payments, refunds, adjustments, cashier approvals, claims / pre-auth, price book |
| **Accounts** | Patient ledgers, general ledger, chart of accounts, journals, period close / books |
| **Reporting & analytics** | Period totals, financial KPIs, heavy reports |

Clinical UIs deep-link here for cashier work; they do not reimplement it. Optional later: Billing posts settled totals to Accounts as journal drafts — Accounts never becomes a Billing tab.

---

## 13. Implementation map

```
presentation/pages/billing_workspace_page.dart
presentation/billing_access.dart
controllers/billing_workspace_controller.dart
widgets/
  billing_detail_widgets.dart          # one Detail shell
  billing_receive_payment_dialog.dart  # Pay
  billing_form_dialogs.dart            # Issue / Send / Refund / Adjust / Void / Approve / …
  billing_quick_charge_dialog.dart     # Charge
  billing_price_book_panel.dart
  billing_workspace_table_support.dart
```

Payment history stays inside Detail. No ledgers panel and no analytics panel in Billing.

---

## 14. Acceptance

- [ ] Six tabs: Open work · To issue · Collect due · Open claims · Need approval · Price book
- [ ] Every tab has a ≤2-word label and a full-sentence tooltip
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Pay / Issue / Approve / Submit
- [ ] Ledger deep-links to Accounts Patient ledgers
- [ ] Default columns ≤5; status filters are tab-scoped
- [ ] Unauthorized tabs / actions are absent
- [ ] Chrome and mutate / refresh flow match `/hr`
- [ ] Every Print opens preview with section options; printout is well laid out (§17)
- [ ] No raw UUIDs appear in Billing UI, printouts, or user-visible URLs (§19)
- [ ] Every create/update dialog runs similarity review before commit (§18)

---

## 15. Out of scope

| Item | Home |
|---|---|
| SaaS subscriptions | `/subscriptions` |
| Patient ledgers, GL, journals, books | `/accounts` — `accounts.md` |
| Clinical ordering | Clinical modules → deep-link Billing |
| Period analytics / heavy reporting | Reporting & analytics |

---

## 16. HR → Billing chrome map

| HR | Billing |
|---|---|
| Human resources | Billing |
| Positions | Price book |
| Work queues | Open work / To issue / Collect due / Open claims / Need approval |
| Staff detail | Detail (+ Ledger → Accounts) |
| Trailing create on one tab | Charge on Open work; Add on Price book; Close on Collect due |

---

## 17. Print preview contract

Every Billing print path (invoice, receipt, claim summary, approval packet, price list export-print) **must**:

1. Open the shared **print preview** dialog/workspace **before** sending to the printer (reuse `AppPrintPreviewWorkspace`, `AppPrintPreviewToolbar`, `AppReportSectionPicker` — same pattern as HR staff / clinical summary print).
2. Offer **comprehensive section options** so the user chooses what appears on the printed output. Defaults are sensible; at least one content section must stay selected to enable Print.
3. Live-update the preview when section options change (split / sections / preview pane modes).
4. Produce **well-laid-out, visually appealing** output: facility branding header/footer, clear hierarchy, readable typography, aligned money columns, consistent spacing, page breaks that do not clip tables, light-theme print CSS suitable for paper.
5. Show only human-readable identifiers on the printout (§19) — never raw UUIDs.
6. Support zoom, page navigation, Copy/Print actions from the preview toolbar; omit Print when no section is selected.

### Invoice / Detail print sections (toggle)

| Section | Default | Contents |
|---|---|---|
| Header / facility | on | Facility name, logo, address, document title |
| Patient | on | Display name, MRN / patient friendly id, contact (if present) |
| Invoice summary | on | Invoice number, status, issued/due dates, totals |
| Line items | on | Item · Qty · Unit · Amount |
| Payments | on when present | Method · Reference · Amount · Date |
| Adjustments | on when present | Type · Reason · Amount |
| Insurance / shares | on when claim-related | Scheme · Patient share · Insurer share |
| Notes | off | Free-text notes |
| Footer / signature | on | Printed-by · timestamp · page |

### Receipt print sections (Pay)

Header · Patient · Invoice reference · Payment (amount/method/reference) · Balance remaining · Footer. Same preview chrome.

### Claim / approval print sections

Header · Patient · Invoice · Claim/insurer fields · Status / decision · Notes · Footer.

Do **not** print silently from Detail or Pay. Do **not** invent a second print stack outside shared printing.

---

## 18. Similarity checks (create & update)

Every **create** and **update** flow that saves Billing-owned records must run similarity review before commit, mirroring `AppSimilarity*` / catalog similarity dialogs used elsewhere.

| Flow | Compared fields (min) | Behavior |
|---|---|---|
| **Charge** (create draft) | Patient · Item · Encounter · Mode · Qty/amount window | Near: review → Select existing draft / Continue create. Exact open draft: prefer open existing. |
| **Price Add** | Item · Mode · Scheme · Effective | Exact active row: block create, offer Select. Near: Select / Overwrite / Continue. |
| **Price Edit** | Same, excluding self | Exact clash with another row: block. Near: warn + confirm. |
| **Adjust** (create request) | Invoice · type · amount | Near pending adjust: review before submit. |
| **Send / Issue metadata updates** that rename or retarget identifiable fields | Relevant identity fields | Same review pattern when a conflicting open document exists. |

Rules:

1. Show loading while similarity runs; empty “no matches” may proceed.
2. Exact full-parameter match on create must not silently duplicate — Select existing or explicit Continue when product allows override.
3. Similarity UI shows proposed vs existing field rows with scores; never show UUIDs.
4. Unauthorized users never see write dialogs; similarity is part of the write path only.
5. After Select existing, land on that record’s Detail / edit surface and refresh lists.

---

## 19. Identifier display (no UUIDs)

| Surface | Show | Never show |
|---|---|---|
| Tables | Invoice number, patient name/MRN, encounter code, item code | Raw UUID / internal PK columns |
| Detail / dialogs | Same + human_friendly_id where useful as a secondary label | UUID as primary title or copy target |
| Filters / search | Resolve by friendly id / code / name | Require pasting a UUID |
| Deep links user can read | Prefer friendly ids in query values when the API supports them | Leak internal UUIDs into chrome the user copies |
| Print / export | Friendly ids and business numbers only | UUID strings in headers or tables |
| Snackbars / errors | Business labels | “id=550e8400-…” |

Internal IDs may exist in repositories and wire DTOs mapped at the data boundary; presentation must not render them.
