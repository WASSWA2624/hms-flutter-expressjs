# Accounts Invoices — Create Invoice dialog UX

## Context

### Current implementation (baseline)

Accounts **Invoices** desk (`/accounts?section=invoices`) is live: list with search / Filters / Settings / Export / Print / primary **+ Create invoice**, empty state (“No invoices match.”), create/edit via `showAccountsInvoiceEditorDialog`, details via `showAccountsInvoiceDetailsDialog`, void-with-reason, and backend `/api/v1/accounts-invoices`.

Screenshots of the current create flow (flat form, not yet sectioned):

- Toolbar primary: **+ Create invoice**
- Create dialog title: **CREATE INVOICE** (maximized `AppDialog` / workspace action dialog)
- Single flat body: Payee*, Invoice date*, Reference, Currency (UGX), Notes, then inline “Item name” / Add item fields (not an items table)
- Footer: **Save** (not “Create Invoice”); no dedicated dialog Close in the action row beyond header X
- After save: snackbar + list refresh; does **not** auto-open Invoice details
- Details: Print / Edit / Delete / Close as tertiary actions; Print uses list-table print helper, not a dedicated invoice print-preview surface

Preserve the Invoices desk list, filters, export/print of the table, edit/void flows, RBAC, and API contracts unless a requirement below forces a glue change.

Follow `prompts/.cursor/` (`prompt.mdc`, `dialogs.mdc`, `forms.mdc`, `tables.mdc`, `printing.mdc`, localization / theming / responsiveness). Reference those files; do not restate them.

### Intended behavior (delta only)

Tighten Create Invoice UX: shorter primary label, branded dialog chrome, two `AppCollapsibleSection`s (Payee + Items), line items managed via table + nested Add/Edit Item dialog, footer Create Invoice + Close, and post-create → details → print preview.

## Definitions

- **Create button (toolbar)** — Invoices desk primary action; label **Create** (no “invoice” word).
- **Payee section** — Collapsible block with payee, invoice date, notes only (no currency field, no reference field).
- **Items section** — Collapsible block hosting an `AppListTable` of draft line items plus **Create item** / row Edit / Delete.
- **Create Item dialog** — Nested dialog to add or edit one line: item name*, description (optional), quantity*, unit price*.
- **Invoice details (post-create)** — Dialog shown immediately after successful create; footer **Print** and **Close**.
- **Print preview** — Existing print-preview path opened from details Print; shows the invoice content to print.

## Requirements

### A. Preserve desk

1. Keep Invoices list, search, Filters, Settings, Export, list Print, empty/loading/error, row→details, Edit, Delete-with-reason, and write/export RBAC omission unchanged except where Required B–F require dialog or label glue.
2. Keep facility-outflow invoice API payloads working: if currency/reference are removed from the UI, still send safe defaults (e.g. facility/default currency such as `UGX`; omit or null reference) so create/update does not break the backend schema.

### B. Toolbar primary label

3. Rename the Invoices desk primary action from **Create invoice** / **+ Create invoice** to **Create** (short label; keep icon if the toolbar pattern uses one). Update `AccountsStrings` / any l10n keys used by that control.

### C. Create Invoice dialog structure

4. Opening **Create** opens the Create Invoice dialog (generic title such as `Create invoice` — no instance id in the title). Use maximized dialog defaults per `dialogs.mdc`.
5. Give the dialog appropriate branded chrome consistent with other Accounts workspace dialogs (existing dialog icon/logo pattern if the shell already supports one; do not invent a one-off header brand system).
6. Split the body into exactly two sibling `AppCollapsibleSection`s (do not nest sections):
   - **Payee** (or equivalent short title): payee*, invoice date*, notes (optional).
   - **Items**: draft line-items table + create control.
7. Remove **Currency** and **Reference** fields from the Create (and Edit) invoice UI.
8. Dialog footer actions (right-aligned, one row per `dialogs.mdc`): primary **Create Invoice** (create mode) / **Save** or existing edit submit label (edit mode), and **Close** / Cancel that dismisses without saving. Omit unauthorized submit; header close remains.

### D. Items table and Create Item dialog

9. In the Items section, render draft lines with `AppListTable` (not stacked free-form fields). Columns: item name, description, quantity, unit price (and derived line total if the desk already shows totals—keep cells short).
10. Items section `headerActions` (or equivalent section action): **Create item** (short label). Clicking opens the Create Item dialog.
11. Create Item dialog fields: item name* (required), description (optional), quantity* (required, > 0), unit price* (required, ≥ 0). Validate before accept; block empty name / invalid qty / invalid price.
12. Confirming Create Item appends a row to the draft table and closes the item dialog; cancel/close leaves the table unchanged.
13. Each items-table row exposes **Edit** and **Delete** when the user can mutate the draft (create/edit invoice). Edit reopens the Create Item dialog with that row; Delete removes the row from the draft (no server call until invoice create/save). Unauthorized or locked invoices omit these controls.
14. Creating the invoice requires ≥ 1 valid line item; show validation feedback if the items table is empty on Create Invoice.

### E. Post-create details and print

15. On successful **Create Invoice**, persist via the existing repository, refresh the Invoices list and tab counts, then open **Invoice details** for the new invoice (do not stop at snackbar-only).
16. Invoice details footer (or pinned actions): **Print** and **Close**. Print opens the print preview for this invoice; Close dismisses details (and does not reopen create). Keep Edit / Delete-with-reason on details only when already allowed today—do not remove them unless they conflict with the Print/Close footer; prefer progressive disclosure consistent with sibling Accounts detail dialogs.
17. Print preview shows the invoice content operators expect to print (payee, date, notes if any, line items, totals) using existing Accounts/`printing.mdc` helpers and the same export/print permission gate as other Accounts prints. Omit Print when unauthorized.

### F. Edit parity and states

18. Edit Invoice reuses the same two-section layout (Payee + Items table + Create Item dialog); submit updates then refreshes list/counts (opening details after edit is optional—default: close editor and refresh, preserving today’s edit outcome unless create’s post-save details flow is trivially shared).
19. Cover permission-omit, loading, empty items table, validation, error, and success feedback for create, add-item, and print. No silent no-ops.

## Constraints

- Reuse `AppDialog` / `showAppWorkspaceActionDialog`, `AppCollapsibleSection`, `AppListTable`, `AppDateField`, Accounts invoice repository/DTOs, and print helpers—no parallel chrome.
- Do not redesign the Invoices list desk, Billing patient invoices, or unrelated Accounts tabs.
- No drive-by refactors outside this Create Invoice UX delta.
- Backend RBAC/ABAC remains authoritative.

## Out of scope

- App bar logo / hamburger sizing (separate workstream).
- Reintroducing currency/reference UI.
- Cross-desk Create entry points.
- Changing invoice void/reason semantics.

## Acceptance Criteria

- [ ] AC1 (Req 1–2): Invoices desk list/RBAC/API still work; create succeeds without currency/reference fields in the UI.
- [ ] AC2 (Req 3): Desk primary label is **Create**.
- [ ] AC3 (Req 4–8): Create Invoice dialog has two collapsible sections; Payee has payee, date, notes only; footer Create Invoice + Close.
- [ ] AC4 (Req 9–14): Items use `AppListTable`; Create item opens nested form with required name/qty/unit price; row Edit/Delete work; empty items block create.
- [ ] AC5 (Req 15–17): Successful create opens Invoice details; Print opens print preview; Close dismisses; Print omitted when unauthorized.
- [ ] AC6 (Req 18–19): Edit uses the same sectioned layout; validation/error/success states are visible.

## Verification

- Manual: Invoices → **Create** → fill payee/date/notes → **Create item** (two lines) → Edit one line → Delete one → **Create Invoice** → details opens → **Print** preview → **Close**.
- Manual: Create with zero items → blocked with validation; unauthorized write → no Create; unauthorized export → no Print on details.
- Manual: light/dark and a narrow viewport — sections, table, and footer actions remain usable.
- Tests: update/add coverage for create dialog section structure, item dialog validation, and post-create details handoff if existing Accounts dialog tests can host it; run touched Accounts tests + analyze changed paths.

## Relevant Files

- `frontend/lib/features/accounts/presentation/widgets/accounts_invoices_panel.dart` (primary **Create** label)
- `frontend/lib/features/accounts/presentation/widgets/accounts_invoice_dialogs.dart` (create/edit/details)
- `frontend/lib/features/accounts/presentation/accounts_strings.dart`
- `frontend/lib/features/accounts/domain/entities/accounts_entities.dart` (`AccountsInvoiceDraft` / line items)
- `frontend/lib/features/accounts/data/repositories/accounts_invoice_repository_impl.dart`
- `frontend/lib/shared/components/app_collapsible_section.dart` (or shared export via `components.dart`)
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
