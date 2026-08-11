# Billing — Price book

## Context

Implement the **Price book** desk section (`?section=prices`) on `/billing` per `billing.md`. This is the CRUD table of service and item prices used when charging. Source of truth: root `billing.md` §§2–8, 9–11.

## Requirements

1. Show the Price book tab with label **Price book** and tooltip: *Service and item prices used when charging*.
2. Persist and write URL `/billing?section=prices` (accept aliases `price-book`, `?tab=prices`).
3. Render search-bar chrome: Search · Filters · Table settings · Export · trailing **Add** only when the user has price-book write (pricing / admin write).
4. Default columns (≤5): Item · Mode · Price · Status · Actions. Optional via settings: Catalog · Scheme · Effective. Persist as `billing_prices_v1`.
5. Search with debounce appropriate to the shared Billing table contract. Filters are scoped to price-book fields (status, catalog, scheme, effective) — not the invoice work-queue status dump.
6. Show empty copy *No prices match.* when empty; show loading, error, validation, and success (snackbar) states for load and save.
7. Trailing **Add** opens Price create dialog (Item · Mode · Price · Scheme · Effective · Active) with primary **Save**.
8. Row Actions support Edit / Deactivate when authorized; row click opens the edit dialog. On save, snackbar and refresh the table.
9. Gate tab with billing workspace access ∩ `billing-payments`. Price writes use pricing / admin write. Omit unauthorized Add / Edit / Deactivate; no disabled “no access” chrome.
10. Do not show a strip Next-action column for this CRUD table; Actions column owns row mutations.
11. After create / update / deactivate, synchronize the price list used by Charge resolution on Open work.
12. Keep the first viewport as strip + table only (no KPI cards). Match `/hr` / Billing chrome.

## Constraints

- Do not add Charge, Pay, Close shift, or Issue all trailing on this tab.
- Do not host Analytics or Reporting inside Price book.
- Reuse Billing workspace page, access gates, price-book panel / dialogs, and shared table support.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Price book is visible with the specified label and tooltip when authorized. (R1, R9)
- [ ] AC2: `/billing?section=prices` and alias `price-book` select Price book and write `section=prices`. (R2)
- [ ] AC3: Default columns are Item · Mode · Price · Status · Actions; settings key `billing_prices_v1`. (R4)
- [ ] AC4: Empty state shows *No prices match.*; loading, error, and validation feedback are visible. (R6)
- [ ] AC5: Authorized **Add** creates a price via one dialog → Save → snackbar → refresh. (R3, R7, R11)
- [ ] AC6: Authorized Edit / Deactivate work from Actions or row click; unauthorized variants are absent. (R8, R9)
- [ ] AC7: Without price write, Add / Edit / Deactivate are absent (not disabled); read-only browse may remain. (R9)
- [ ] AC8: No work-queue Next column and no cashier trailing actions on this tab. (R3, R10)
- [ ] AC9: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3, R12)

## Verification

- Permissions tests: Add / Edit / Deactivate absent without pricing/admin write; tab readable with billing access.
- Flow tests: create, edit, deactivate refresh the table; Charge on Open work can resolve book prices after save (integration or manual).
- Manual check: empty/loading/error/validation, optional columns, viewports, themes.
- Confirm no Analytics / Ledgers / Payments tab introduced via this work.

## Relevant Files

- `billing.md`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_price_book_panel.dart` (or equivalent price panel)
- `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`
- `frontend/test/features/billing/presentation/billing_access_test.dart`
- `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`
