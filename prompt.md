# Refine Billing Invoice Detail Dialog

## Goal

Improve the **Invoice Detail** dialog in the Billing workspace so patient and invoice context is scannable, metadata uses consistent **label:value** pairs, line items are tabular, and billing actions remain fully functional.

## Scope

- Primary: `frontend/lib/features/billing/presentation/widgets/billing_detail_widgets.dart` (`BillingDetailBody` and related private sections)
- Related: `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart` (payment/issue/refund/adjust/void/send dialogs)
- Reuse existing shared components; do not introduce one-off styling

## Reference patterns

- **Inline label:value facts:** `PatientDetailHeader` (`patient_detail_header.dart`) — `AppWorkspacePatientContextHeader` with `fieldStyle: AppWorkspacePatientContextFieldStyle.inline`, `showAvatar: false`
- **Tables:** `AppListTable` (billing workspace list, lab workspace)
- **Quick actions:** `AppActionList` / `AppActionItem` (already used in `_BillingActionPanel`)
- **Financial cards:** `AppReportPreviewPanel` + `AppReportSummaryGrid` (keep card layout here only)

---

## 1. Patient & invoice context header

Replace the current tile/card layout in `AppWorkspacePatientContextHeader` with **inline label:value pairs** (`Label: Value`), each with an icon where appropriate. **Remove the patient avatar.**

### Row 1 — Patient identity (single row; wrap only when width is insufficient)

| Field | Example | Notes |
|-------|---------|-------|
| Patient name | `Patient name: Wilson Wasswa` | Move out of standalone title styling into inline fact |
| Patient ID | `Patient ID: PAT0000001` | Copyable |
| Payment status | `Status: Awaiting payment` | Clearance state (`BillingGateBadge` tone/icon) |
| Gender | `Gender: Male` | Show when available |
| Age | `Age: 32 yrs` | Use `formatPatientAge` pattern from patient module |
| Encounter | `Encounter: ENC0000001` | **Move here** from the invoice-metadata row |

> **Data:** `BillingWorkItem` currently lacks gender/age. Extend DTO/entity (`billing_dtos.dart`, `billing_entities.dart`) and map from API if fields exist; otherwise omit gracefully (do not show empty placeholders).

### Row 2 — Invoice metadata (inline facts, **no tile cards**)

| Field | Example |
|-------|---------|
| Invoice | `Invoice: INV0000004` (copyable) |
| Invoice status | `Status: Issued` |
| Amount paid | `Amount paid: UGX 0` |
| Balance | `Balance: UGX 95,000` |

Use `AppWorkspacePatientContextFieldStyle.inline` for both rows. Preserve tone coloring for paid/balance where applicable.

---

## 2. Quick actions

Keep the existing action bar (`Receive payment`, `Issue`, `Refund`, `Adjust`, `Void`, `Send`) grouped under a clear **Quick actions** section using `AppActionList`.

- **Receive payment:** Extract the payment form/dialog (`_PaymentForm` in `billing_workspace_page.dart`) into a **reusable shared widget** and use it wherever payment is received (invoice detail and any other billing entry points).
- **Issue / Refund / Adjust / Void / Send:** Preserve current enablement rules (`canIssue`, `canRequestRefund`, etc.) and controller wiring; no behavior regressions.

---

## 3. Financial summary

Keep the **card grid** (`AppReportPreviewPanel` + `AppReportSummaryGrid`) but ensure each card shows an explicit **label:value** presentation:

| Card label | Maps to |
|------------|---------|
| **Total amount** | `item.effectiveTotal` (invoice opening balance) |
| **Amount paid** | `item.paidAmount` |
| **Balance** | `item.balanceDue` |

Icons may remain. Wording must be unambiguous (avoid duplicating “Status” labels used elsewhere).

---

## 4. Line items → table

Replace the current list rows (title + concatenated subtitle like `Qty 1 · Laboratory · ENC0000001`) with an **`AppListTable`** (or equivalent shared table) where **each datum occupies its own column** — no multi-value cells.

Suggested columns:

| Column | Source (`BillingInvoiceItem`) |
|--------|-------------------------------|
| Description | `description` |
| Qty | `quantity` |
| Unit price | `unitPrice` (formatted) |
| Department | `sourceModule` |
| Encounter | `encounterDisplayId` |
| Amount | `totalPrice` (formatted with invoice currency) |

Include empty-state text when `item.items` is empty. Match table density/styling used elsewhere in billing.

---

## 5. Payments & adjustments

No layout change required unless applying the same one-value-per-column principle improves readability. Keep existing empty states.

---

## Constraints

- Follow existing theme tokens, spacing, and l10n keys; add ARB entries only where labels are new.
- Minimize diff scope — refactor header layout and line-items table; do not redesign unrelated billing flows.
- All actions must continue to refresh invoice state after mutation.

## Acceptance criteria

- [ ] Invoice detail opens with **no avatar**; patient + encounter facts on row 1, invoice facts on row 2, all as inline `Label: Value` pairs with icons.
- [ ] Invoice metadata row uses **inline facts, not tile cards**.
- [ ] Financial summary cards show **Total amount**, **Amount paid**, and **Balance** clearly.
- [ ] Line items render in a **table with one value per column** (screenshot-style concatenation removed).
- [ ] Quick actions visible and functional; **Receive payment** uses a shared reusable form component.
- [ ] Existing billing widget tests updated or added where behavior changed.
