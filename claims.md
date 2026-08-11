# Claims — complete screen blueprint

Source of truth for the **Claims** workspace (insurance claims desk). Mirror **Human resources** (`/hr`), **Billing** (`/billing`), and **Accounts** (`/accounts`): one gated page, short desk tabs, `AppListTable` chrome, row → detail dialog.

**Claims is the only insurance desk.** Pre-authorizations, active claim lifecycle, remittance close, settled review, and insurer catalog setup live here. No parallel claims UIs.

**Billing** (`/billing`, `billing.md`) owns the cashier desk (invoices, collect, charge, price book). Billing **Open claims** may deep-link here for full claim work; Claims must not absorb Collect due / Charge. Patient residual co-pay opens Billing receive-payment only.

**Accounts** (`/accounts`, `accounts.md`) owns patient ledgers and facility books. Claims does not host ledgers.

**Reporting & analytics** owns period totals and financial KPIs. Claims does not host an Analytics tab.

| | |
|---|---|
| **Nav / title** | Claims |
| **Route** | `/claims` |
| **Module** | `insurance-claims` |
| **Mirror** | `/hr` · `/billing` · `/accounts` |
| **Sibling** | **Billing** Open claims — cashier handoff, not a Claims tab |
| **Reports** | **Reporting & analytics** — not a Claims tab |

---

## UX principles (non-negotiable)

1. **Informative short labels** — tab labels use **up to 2 words**. Tooltips carry a full descriptive sentence. Row Next and trailing buttons stay 1–2 words with tooltips.
2. **No duplicate surfaces** — each capability has one home. Do not repeat the same trailing action on every tab. Do not add a second tab that only restates another queue.
3. **Short flows** — happy path is **row Next → one modal → save**. Detail is for review and secondary actions, not a required stop.
4. **Progressive disclosure** — tables stay lean (≤5 default columns). Extra columns via Table settings. Extra actions inside Detail.
5. **Adaptability** — fewer tabs, shared table contract, shared Detail shell. New claim sources plug into Authorizations / Active claims without new screens.
6. **Human-readable IDs only** — never display raw UUIDs or internal primary keys in tables, Detail, dialogs, filters, snackbars, printouts, or URLs the user sees. Use `human_friendly_id`, claim/auth references, patient display names/MRNs, coverage plan codes, and invoice numbers.
7. **Print = preview first** — every Print / statement path opens the shared print-preview workspace with comprehensive section options before printing. Printed layout must be branded, well spaced, and visually clear (see §17).
8. **Similarity on create/update** — every create and update dialog runs similarity review before commit when near/exact matches exist (see §18).

---

## 1. Screen shell

```
AppAccessGate
└── AsyncStateScaffold ("Claims")
    └── ResponsivePage (dataHeavy, scrollable: false)
        └── Column
            ├── AppTabStrip  (≤2-word label + count; tooltip on hover/focus)
            └── Expanded → one table / panel
```

Rules:

1. No app-bar trailing actions.
2. First viewport = strip + one body. No KPI cards above the table. Summary chips on Authorizations / Active claims are **filter chips** (like Collect due Overdue), not KPI dashboards.
3. Count tones: Authorizations / Active claims = warning · Settled / Insurance setup = info.
4. Fallback tab when unauthorized: **Authorizations** (first allowed section).
5. Snackbars for mutations; no sticky banner between strip and table.
6. Realtime + light poll on the active section.

### Search-bar order (every queue table)

```
[ Search ]  [ Filters ]  [ Table settings ]  [ Export ]  [ trailing — only where owned ]
```

Insurance setup uses a setup panel (quick actions), not the queue table chrome.

---

## 2. Tabs (≤2-word labels + tooltips)

`ClaimsDeskSection` · URL `/claims?section=<slug>` (alias `?tab=` / `?panel=` / `?filter=`).  
Display labels may be two words; **`?section=` slugs stay stable** (do not rename slugs when labels change).

| # | Label | Tooltip | Enum | `?section=` | Body | Count |
|---|---|---|---|---|---|---|
| 1 | **Authorizations** | Pre-authorizations awaiting request, approval, or status update | `authorizations` | `authorizations` | Work queue | Pending + approved open |
| 2 | **Active claims** | Submitted and in-flight insurance claims awaiting response or close | `activeClaims` | `active-claims` | Work queue | Submitted + approved + partial + rejected |
| 3 | **Settled** | Paid and cancelled claims for review only | `settled` | `settled` | Review queue | Paid / closed |
| 4 | **Insurance setup** | Payers, schemes, offers, enrollments, tariffs, and insurer API | `insuranceSetup` | `insurance-setup` | Setup panel | — |

**Aliases (compat):** `active_claims` → `active-claims` · `insurance_setup` → `insurance-setup` · `preauth` / `pre-auth` → `authorizations` · `claims` / `open-claims` → `active-claims` · `paid` / `closed` → `settled` · `setup` / `catalog` → `insurance-setup` · `analytics` → Reporting & analytics · Billing cashier → `/billing`.

---

## 3. Shared work-queue contract

Used by **Authorizations · Active claims · Settled**.

| Control | Spec |
|---|---|
| **Search** | ~350ms debounce. Hint: *Search reference, coverage, invoice, or patient* |
| **Filters** | Status chips / sheet scoped to the tab. **Settled** adds advanced Filters (Paid / Cancelled). Authorizations / Active claims use summary filter chips. |
| **Status choices** | Only statuses that exist on that tab (no global dump). |
| **Table settings** | Persist `claims_<section>_v1` (or `claims_${section.name}` storage key) |
| **Export** | Current filtered rows when authorized |
| **Default columns** | ≤5. Pool below; extras via settings. |
| **Row click** | Shared **Detail** dialog (kind-aware body: pre-auth vs claim). |
| **Next action** | Single primary button. Unauthorized → omit (no disabled “no access” chrome). Settled has no Next. |

### Column pool (short headers)

| ID | Header | Default on |
|---|---|---|
| `reference` | Reference | all queues |
| `patient` | Patient | all queues |
| `coverage` | Coverage | all queues |
| `status` | Status | all queues |
| `settlement` | Settlement | Settled |
| `next` | Next | Authorizations / Active claims when user can act |
| `approved_amount` | Approved | optional Authorizations |
| `requested_at` | Requested | optional Authorizations |
| `invoice` | Invoice | optional Active claims / Settled |
| `claim_amount` | Amount | optional Active claims / Settled |
| `submitted_at` | Submitted | optional Active claims |
| `timeline` | Updated | optional Settled |

---

## 4. Tab specs

### 4.1 Authorizations (`authorizations`)

Pre-auth queue. Approved limits constrain Billing coverage splits — this tab does not collect cash.

| | |
|---|---|
| **Columns** | Reference · Patient · Coverage · Status · Next |
| **Optional** | Approved · Requested |
| **Empty** | *No authorizations in this queue.* |
| **Trailing (owned here)** | **Request** |
| **Filters / chips** | Pending · Approved · Denied · Expired |
| **Next** | **Update** |
| **Deep link** | `?section=authorizations&action=preauth` → Request modal |
| **Row click** | Detail (Print when authorized; billing-impact read panel) |

### 4.2 Active claims (`active-claims`)

In-flight claims. Remittance settle posts through shared Billing claim-remittance — never a claims-local cashier.

| | |
|---|---|
| **Columns** | Reference · Patient · Coverage · Status · Next |
| **Optional** | Invoice · Amount · Submitted |
| **Empty** | *No claims in this queue.* |
| **Trailing (owned here)** | **Prepare** |
| **Filters / chips** | Submitted · Approved · Partial · Rejected |
| **Next** | **Submit** · **Respond** · **Resubmit** · **Close** (by status) |
| **Deep link** | `?section=active-claims&action=prepare` → Prepare modal |
| **Row click** | Detail (secondary: **Sync**, **Collect** → Billing when residual due, Print) |

### 4.3 Settled (`settled`)

Review-only paid / cancelled claims. No prepare, submit, sync, or close mutations.

| | |
|---|---|
| **Columns** | Reference · Patient · Coverage · Settlement · Status |
| **Optional** | Invoice · Amount · Updated |
| **Empty** | *No settled claims.* |
| **Trailing** | none |
| **Filters** | Paid · Cancelled (advanced Filters) |
| **Next** | none |
| **Row click** | Detail (Print / export when nested export ∪ allows; billing-impact read panel) |

### 4.4 Insurance setup (`insurance-setup`)

Catalog panel — companies, schemes, offers, enrollments, price-book tariffs, insurer API. Creates persist catalog rows only; they do **not** post patient invoices or payments.

| | |
|---|---|
| **Body** | Description + quick-action creates (not a queue table) |
| **Trailing** | none on strip (creates live on panel) |
| **Actions** | **Add company** · **Add scheme** · **Add offer** · **Enroll** · **Add price** · **Insurer API** |
| **Empty create strip** | Hide when user lacks write (no disabled stubs) |
| **Row / Detail** | n/a for queue; nested create dialogs only |

---

## 5. Trailing actions (one owner each)

| Button | Label | Owner tab only | Opens |
|---|---|---|---|
| Request | *Request* | Authorizations | Request pre-authorization modal |
| Prepare | *Prepare* | Active claims | Prepare claim modal |

No other trailing / strip-primary buttons. Do not re-add Request / Prepare on Settled or Insurance setup. Insurance setup creates stay on the setup panel.

---

## 6. Next actions (short labels)

| Label | Tooltip | Opens |
|---|---|---|
| **Update** | Update this pre-authorization status | Update authorization modal |
| **Submit** | Submit this claim to the insurer | Submit claim modal |
| **Resubmit** | Resubmit this rejected claim | Submit claim modal |
| **Respond** | Record the insurer response | Record response modal |
| **Close** | Close this approved claim as paid | Close as paid modal |
| **Sync** | Sync insurer status for this claim | Detail only (Active claims) |
| **Collect** | Collect patient residual in Billing | `/billing?section=collect&action=pay&…` |
| **Print** | Preview and print the statement | Print preview (§17) |

One Next button per row. Everything else waits in Detail. Settled omits Next entirely.

---

## 7. Flows (keep short)

### Happy paths (1 step)

| Intent | Flow |
|---|---|
| Request pre-auth | Authorizations → **Request** → save |
| Update pre-auth | Authorizations → **Update** → status/notes → save |
| Prepare claim | Active claims → **Prepare** → invoice + coverage → save |
| Submit / resubmit | Active claims → **Submit** / **Resubmit** → save |
| Record response | Active claims → **Respond** → status/settlement → save |
| Close as paid | Active claims → **Close** → confirm → remittance via Billing path |
| Collect residual | Active claims Detail → **Collect** → Billing Collect due |
| Catalog create | Insurance setup → Add company / scheme / offer / enroll / price / API → save |

### Detail path (only when needed)

Row click → **Detail** → secondary action (Sync / Collect → Billing / Print).

Do **not** require Detail before Update / Submit / Respond / Close / Prepare / Request.

### Anti-patterns (forbidden)

- Two tabs showing the same queue under different names
- Request / Prepare outside their owner tabs
- Collect / Charge / Issue implemented inside Claims (deep-link Billing only)
- Settled hosting mutate / Sync / Prepare / Close
- Insurance setup posting invoices, payments, or remittances
- Modal that only opens another modal before the user can finish
- Analytics or Accounts ledger tabs inside Claims
- Tab labels longer than 2 words (put detail in the tooltip)

---

## 8. Dialogs (shared, minimal)

One **Detail** shell; body switches by kind (pre-auth vs claim). Remittance and residual collect reuse Billing paths.

### 8.1 Detail

**Titles (short):** Authorization · Claim

**Always:** patient / coverage header · status · amount summary tiles (approved / claim / settlement / billing impact when present) · primary quick actions (same labels as §6 when capable)

**Sections (progressive):** Coverage / invoice refs → Amounts → Timeline / notes (collapsed/empty omitted) → Billing impact (read)

**Actions shown only if capable:** Update · Submit · Resubmit · Respond · Close · Sync (Active claims) · Collect (→ Billing) · Print · Download

**Identifiers:** claim/auth reference, patient name/MRN, coverage code, invoice number — never UUIDs.

### 8.2 Request authorization

Patient · Encounter (optional) · Coverage · Reason · Requested amount (optional) · Notes. Primary: **Request**.  
**Before save:** similarity against near-duplicate open pre-auths (patient · coverage · encounter · amount window) (§18).

### 8.3 Update authorization

Status · Approved amount (when approving) · Notes. Primary: **Update**.

### 8.4 Prepare claim

Invoice · Coverage · Notes. Primary: **Prepare**. Links existing Billing invoice — no new charge.  
**Before save:** similarity against near-duplicate open claims for same invoice / coverage (§18).

### 8.5 Submit / Resubmit

Optional notes. Primary: **Submit** / **Resubmit**.

### 8.6 Record response / Close as paid

Status · Settlement amount (when settling) · Notes. Primary: **Respond** / **Close**.  
PAID / PARTIAL requires `financial:approve` ∩ `insurance-claims` and posts remittance via shared Billing claim-remittance.

### 8.7 Insurance setup creates

Company · Scheme · Offer · Enrollment · Price book · Insurer API — each one dialog, required fields only. Primary: **Save**.  
**Before save:** similarity on natural keys (company code/name; scheme code; offer scheme+item; enrollment patient+scheme; price item+scheme+effective) (§18).  
Enrollment stays PENDING until an explicit verify path activates payer context — no silent auto-verify.

### 8.8 Print preview

Opened from Detail **Print**. Reuse `AppPrintPreviewWorkspace` / `AppReportSectionPicker` (mirror HR / Billing / Accounts). See §17.

---

## 9. Permissions

| Layer | Gate |
|---|---|
| Route entry | `claims:read` ∩ `insurance-claims` (catalog atom) |
| Queue read (Authorizations / Active claims / Settled) | `billing:read` ∩ `insurance-claims` |
| Insurance setup tab | (`billing:read` ∪ `facility:admin` ∪ `tenant:admin`) ∩ `insurance-claims` |
| Write (Request / Update / Prepare / Submit / Resubmit / Respond / Sync / catalog create) | `billing:write` ∩ `insurance-claims` |
| Close as paid / PAID·PARTIAL remittance | `financial:approve` ∩ `insurance-claims` |
| Settled Print / export | (`reports:read` ∪ `evidence:export`) ∩ `insurance-claims` |
| Collect residual | (`billing:write`) ∩ `billing-payments`; omit if unauthorized |

Hide unauthorized tabs and actions. Do not render disabled “no access” controls.

---

## 10. Deep links

| Query | Effect |
|---|---|
| `section` / `tab` / `panel` / `filter` | Desk section |
| `search` / `q` | Prefill search |
| `encounterId` / `patientId` | Open matching queue Detail after load |
| `action=preauth` | Open Request on Authorizations |
| `action=prepare` / `prepare-claim` | Open Prepare on Active claims |

URL write: `/claims?section=<slug>`.

---

## 11. Controller flow

```
load workspace → applySection / search / filters / page
mutate (one call) → snackbar → refresh active section + open detail if still needed
realtime while idle
```

Copy: *Saved.* · standard save / fail strings.

---

## 12. Domain ownership

| Owner | Owns |
|---|---|
| **Claims** | Pre-authorizations, claim prepare/submit/respond/close, settled review, insurer catalog (companies, schemes, offers, enrollments, claim tariffs, insurer API) |
| **Billing** | Invoices, charge events, payments, refunds, adjustments, cashier approvals, price book used at charge time, Open claims cashier handoff |
| **Accounts** | Patient ledgers, general ledger, chart of accounts, journals, period close / books |
| **Reporting & analytics** | Period totals, financial KPIs, heavy reports |

Other modules may deep-link here for pre-auth / prepare; they do not reimplement claims flows. Coverage % and tariffs enter Billing only via price-resolver / coverage-split at charge time.

---

## 13. Implementation map

```
presentation/pages/claims_workspace_page.dart
presentation/claims_access.dart
controllers/claims_workspace_controller.dart
widgets/
  claims_insurance_config_dialogs.dart   # setup creates
  insurance_authorization_panel.dart     # clinical embed (not a Claims tab)
domain/entities/
  claims_entities.dart
  claims_authorizations_financial_inventory.dart
  claims_active_claims_financial_inventory.dart
  claims_settled_financial_inventory.dart
presentation/claims_insurance_setup_billing_inventory.dart
```

Detail and form dialogs currently live with the workspace page — keep one Detail shell and one-step action dialogs. No analytics panel. No cashier Collect due / Charge widgets here.

---

## 14. Acceptance

- [ ] Four tabs: Authorizations · Active claims · Settled · Insurance setup
- [ ] Every tab has a ≤2-word label and a full-sentence tooltip
- [ ] Trailing actions have a single owner tab (§5)
- [ ] Happy paths complete from Next → one modal → save
- [ ] Detail is optional for Update / Submit / Respond / Close / Request / Prepare
- [ ] Settled is review-only (no Next / Sync / Prepare / Close)
- [ ] Collect residual deep-links to Billing; no local cashier
- [ ] Default columns ≤5; status filters are tab-scoped
- [ ] Unauthorized tabs / actions are absent
- [ ] Chrome and mutate / refresh flow match `/hr`, `/billing`, and `/accounts`
- [ ] Every Print opens preview with section options; printout is well laid out (§17)
- [ ] No raw UUIDs appear in Claims UI, printouts, or user-visible URLs (§19)
- [ ] Every create/update dialog runs similarity review before commit (§18)

---

## 15. Out of scope

| Item | Home |
|---|---|
| Invoices, collect, charge, cashier price book | `/billing` — `billing.md` |
| Patient ledgers, GL, journals, books | `/accounts` — `accounts.md` |
| Period analytics / heavy reporting | Reporting & analytics |
| Clinical ordering / encounter charting | Clinical modules → deep-link Claims for pre-auth |

---

## 16. HR / Billing / Accounts → Claims chrome map

| HR / Billing / Accounts | Claims |
|---|---|
| Human resources / Billing / Accounts | Claims |
| Work queues | Authorizations / Active claims / Settled |
| Positions / Price book / Account chart | Insurance setup |
| Staff / invoice / journal detail | Detail (+ Collect → Billing) |
| Trailing create on one tab | Request on Authorizations; Prepare on Active claims; panel creates on Insurance setup |
| Collect due / Charge / Pay | Stay on Billing; Collect deep-links from Active claims Detail |

---

## 17. Print preview contract

Every Claims print path (authorization statement, claim statement, settled export-print) **must**:

1. Open the shared **print preview** dialog/workspace **before** sending to the printer (reuse `AppPrintPreviewWorkspace`, `AppPrintPreviewToolbar`, `AppReportSectionPicker` — same pattern as HR / Billing / Accounts).
2. Offer **comprehensive section options** so the user chooses what appears on the printed output. Defaults are sensible; at least one content section must stay selected to enable Print.
3. Live-update the preview when section options change (split / sections / preview pane modes).
4. Produce **well-laid-out, visually appealing** output: facility branding header/footer, clear hierarchy, readable typography, aligned money columns, consistent spacing, page breaks that do not clip tables, light-theme print CSS suitable for paper.
5. Show only human-readable identifiers on the printout (§19) — never raw UUIDs.
6. Support zoom, page navigation, Copy/Print actions from the preview toolbar; omit Print when no section is selected.

### Authorization / claim statement sections (toggle)

| Section | Default | Contents |
|---|---|---|
| Header / facility | on | Facility name, logo, address, document title |
| Patient | on | Display name, MRN / patient friendly id |
| Coverage | on | Scheme / plan code · insurer |
| Claim / auth summary | on | Reference, status, dates, amounts |
| Invoice link | on when present | Invoice number, billing status, patient balance |
| Settlement | on when present | Settlement amount · remittance notes |
| Notes | off | Free-text notes |
| Footer / signature | on | Printed-by · timestamp · page |

Do **not** print silently from Detail. Do **not** invent a second print stack outside shared printing.

---

## 18. Similarity checks (create & update)

Every **create** and **update** flow that saves Claims-owned records must run similarity review before commit, mirroring `AppSimilarity*` / catalog similarity dialogs used elsewhere.

| Flow | Compared fields (min) | Behavior |
|---|---|---|
| **Request authorization** | Patient · Coverage · Encounter · amount window | Near open pre-auth: review → Select existing / Continue. Exact twin: prefer open existing. |
| **Update authorization** | Same identity + status change | Clash with conflicting open update: warn + confirm. |
| **Prepare claim** | Invoice · Coverage | Exact open claim for invoice: prefer open existing. Near: Select / Continue. |
| **Submit / Respond metadata updates** that retarget identifiable fields | Relevant identity fields | Same review when a conflicting open document exists. |
| **Add company** | Code · Name | Exact code: block create, offer Select. Near: Select / Overwrite / Continue. |
| **Add scheme** | Code · Name · Company | Exact code: block. Near: review. |
| **Add offer** | Scheme · Item · Effective | Exact active row: block. Near: review. |
| **Enroll patient** | Patient · Scheme · Member id | Exact open enrollment: Select existing. Near: review. |
| **Add price** | Item · Mode · Scheme · Effective | Exact active row: block. Near: Select / Overwrite / Continue. |
| **Insurer API** | Company · Endpoint identity | Exact twin config: Select existing. Near: review. |

Rules:

1. Show loading while similarity runs; empty “no matches” may proceed.
2. Exact full-parameter match on create must not silently duplicate — Select existing or explicit Continue when product allows override.
3. Similarity UI shows proposed vs existing field rows with scores; never show UUIDs (use references, codes, patient name/MRN, invoice numbers).
4. Similarity is part of the write path only; unauthorized users never see write dialogs.
5. After Select existing, land on that record’s Detail / edit surface and refresh lists.

---

## 19. Identifier display (no UUIDs)

| Surface | Show | Never show |
|---|---|---|
| Tables | Claim/auth reference, patient name/MRN, coverage code, invoice number | Raw UUID / internal PK columns |
| Detail / dialogs | Same + human_friendly_id where useful as a secondary label | UUID as primary title or copy target |
| Filters / search | Resolve by friendly id / code / name | Require pasting a UUID |
| Deep links user can read | Prefer friendly ids in query values when the API supports them | Leak internal UUIDs into chrome the user copies |
| Print / export | Friendly ids and business numbers only | UUID strings in headers or tables |
| Snackbars / errors | Business labels | “id=550e8400-…” |

Internal IDs may exist in repositories and wire DTOs mapped at the data boundary; presentation must not render them.
