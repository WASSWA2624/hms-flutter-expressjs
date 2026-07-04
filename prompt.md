# Billing worklist UX improvements

## Context

Refine the **Billing** cashier worklist (`/billing`) in HOSSPI. The page header and actions are acceptable as-is; focus on the worklist panel, table structure, status labeling, search, and filters.

**Keep unchanged**
- Page title and icon
- Primary action: **Close shift**
- Overflow menu: **Close day**, **Refresh**, **Request maintenance**, **Report equipment fault**

## Problems (current state)

1. The worklist panel shows redundant copy: title **“All billing work items”** plus subtitle **“Cashier worklist for invoices, payments, claims, and approvals.”** Remove the subtitle/description.
2. The table stacks **patient ID** and **invoice number** under the patient name. Cashiers need each identifier in its own column for scanning and sorting.
3. **Status** shows **“Blocked”** (red lock) for a normal unpaid invoice (e.g. UGX 95,000 due, UGX 0 paid). That label is misleading—this is pending payment, not a blocked clearance gate.
4. There is no **source** column showing where charges originated (e.g. Laboratory, Pharmacy, OPD).
5. **Billing filters** only expose queue selection. Cashiers need richer filter fields aligned with the table.
6. Search is too narrow. It must support flexible lookup across common billing identifiers.

## Requirements

### 1. Worklist panel header
- Remove `billingWorklistDescription` from the panel (keep the queue title only, e.g. “All billing work items” or active queue name).

### 2. Table columns
Restructure the default visible columns to:

| Column | Content |
|--------|---------|
| Patient name | Display name only (no stacked identifiers) |
| Patient ID | e.g. `PAT0000001` |
| Invoice | e.g. `INV0000004` |
| Encounter | e.g. `ENC0000001` |
| Source | Originating module/service (Lab, Pharmacy, Radiology, OPD, etc.) — use existing invoice line-item source metadata (`sourceModule` / `sourceContextLabel`) aggregated sensibly at invoice level |
| Status | Clear, cashier-friendly billing state (see below) |
| Amount due | Total outstanding |
| Amount paid | Total paid to date |

- Hide or de-emphasize less-critical columns (balance, last updated) via table settings by default if needed.
- Update mobile tile layout to reflect the same fields.

### 3. Status labeling
Replace misleading **“Blocked”** for standard unpaid invoices.

- Map unpaid issued invoices to a label such as **“Awaiting payment”** or **“Unpaid”**, with a warning/neutral tone—not error/red lock.
- Reserve **“Blocked”** (or equivalent) only for true clearance blocks (authorization holds, insurance gates, etc.).
- Review `BillingClearanceState.blocked` usage in `billing_entities.dart` and `billing_support.dart`; align UI labels, icons, and tones with actual business meaning.
- Prefer showing both **invoice status** (`ISSUED`, `PARTIAL`, `OVERDUE`) and **clearance state** where they differ, or pick the most actionable label for the worklist.

### 4. Search
Make the worklist search global and flexible. A single search box should match (partial, case-insensitive where appropriate):

- Patient name (first/last/full)
- Patient ID (`human_friendly_id`)
- Patient email and phone (if available on patient record)
- Invoice number
- Encounter ID

**Backend:** extend `commonInvoiceWhere` in `billing.service.js` beyond current invoice ID + patient name/ID filters.

**Frontend:** update hint/semantic labels to reflect the expanded scope; ensure search is server-driven (not client-only filtering).

### 5. Billing filters dialog
Expand **Billing filters** beyond queue type. Add filter fields for at least:

- Queue / work item type (existing)
- Patient ID
- Invoice number
- Encounter ID
- Source module
- Status (awaiting payment, partial, overdue, draft, etc.)
- Date range (issued / updated)

Wire filters to API query params; persist active filter state in `BillingWorkspaceQuery`.

## Acceptance criteria

- [ ] Worklist panel has no subtitle/description under the queue title.
- [ ] Table shows separate columns for patient name, patient ID, invoice number, encounter, source, status, amount due, and amount paid.
- [ ] An unpaid invoice like `INV0000004` shows **Awaiting payment** (or equivalent)—not **Blocked**.
- [ ] Source column shows where the invoice charges came from (e.g. Laboratory).
- [ ] Search finds rows by patient name, patient ID, invoice number, encounter ID, email, or phone.
- [ ] Billing filters dialog exposes the additional fields and correctly narrows the worklist.
- [ ] Existing header actions (Close shift, Close day, Refresh, maintenance/fault reporting) remain unchanged.
- [ ] Add/update l10n strings in `app_en.arb`; follow existing billing workspace patterns in `billing_workspace_page.dart`.

## Key files

- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_support.dart`
- `frontend/lib/features/billing/domain/entities/billing_entities.dart`
- `backend/src/modules/billing/services/billing.service.js`
- `frontend/lib/l10n/app_en.arb`
