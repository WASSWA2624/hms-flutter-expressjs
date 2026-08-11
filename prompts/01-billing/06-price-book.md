# Billing — Price book

## Context

Implement the **Price book** desk section (`?section=prices`) on `/billing` per `billing.md`. This is the CRUD table of service and item prices used when charging. Source of truth: root `billing.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Price book tab with label **Price book** and tooltip: *Service and item prices used when charging*.
2. Persist and write URL `/billing?section=prices` (accept aliases `price-book`, `?tab=prices`).
3. Render search-bar chrome: Search · Filters · Table settings · Export · trailing **Add** only when the user has price-book write (pricing / admin write).
4. Default columns (≤5): Item · Mode · Price · Status · Actions. Optional via settings: Catalog · Scheme · Effective. Persist as `billing_prices_v1`.
5. Search with debounce appropriate to the shared Billing table contract. Filters are scoped to price-book fields (status, catalog, scheme, effective) — not the invoice work-queue status dump.
6. Show empty copy *No prices match.* when empty; show loading, error, validation, and success (snackbar) states for load and save.
7. Trailing **Add** opens Price create dialog (Item · Mode · Price · Scheme · Effective · Active) with primary **Save**.
8. **Before save on create and update**, run similarity review on Item · Mode · Scheme · Effective against existing price-book rows (`billing.md` §18). Exact active match blocks create (offer Select existing); near match offers Select / Overwrite / Continue.
9. Row Actions support Edit / Deactivate when authorized; row click opens the edit dialog. On save (after similarity), snackbar and refresh the table.
10. Optional **Print** / export-print of the filtered price list opens shared print preview with section options (`billing.md` §17); never print silently.
11. Gate tab with billing workspace access ∩ `billing-payments`. Price writes use pricing / admin write. Omit unauthorized Add / Edit / Deactivate; no disabled “no access” chrome.
12. Do not show a strip Next-action column for this CRUD table; Actions column owns row mutations.
13. After create / update / deactivate, synchronize the price list used by Charge resolution on Open work.
14. Keep the first viewport as strip + table only (no KPI cards). Match `/hr` / Billing chrome.
15. Never display raw UUIDs — use item codes/names and scheme labels (`billing.md` §19).

## Constraints

- Do not add Charge, Pay, Close shift, or Issue all trailing on this tab.
- Do not host Analytics or Reporting inside Price book.
- Do not skip similarity on Add/Edit or print preview when printing.
- Reuse Billing workspace page, access gates, price-book panel / dialogs, shared table support, `AppSimilarity*`, and `AppPrintPreviewWorkspace`.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Price book is visible with the specified label and tooltip when authorized. (R1, R9)
- [ ] AC2: `/billing?section=prices` and alias `price-book` select Price book and write `section=prices`. (R2)
- [ ] AC3: Default columns are Item · Mode · Price · Status · Actions; settings key `billing_prices_v1`. (R4)
- [ ] AC4: Empty state shows *No prices match.*; loading, error, and validation feedback are visible. (R6)
- [ ] AC5: Authorized **Add** runs similarity then creates a price via one dialog → Save → snackbar → refresh. (R3, R7, R8, R13)
- [ ] AC6: Authorized Edit / Deactivate work from Actions or row click; Edit runs similarity; unauthorized variants are absent. (R8, R9, R11)
- [ ] AC7: Without price write, Add / Edit / Deactivate are absent (not disabled); read-only browse may remain. (R11)
- [ ] AC8: No work-queue Next column and no cashier trailing actions on this tab. (R3, R12)
- [ ] AC9: Print (when offered) opens preview with section toggles; printout is branded and well laid out. (R10)
- [ ] AC10: No raw UUIDs appear in Price book UI, similarity, or print. (R15)
- [ ] AC11: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3, R14)

## Verification

- Permissions tests: Add / Edit / Deactivate absent without pricing/admin write; tab readable with billing access.
- Flow tests: create/edit with similarity; deactivate refresh; Charge resolves book prices after save.
- Manual check: empty/loading/error/validation, optional columns, print layout, viewports, themes.
- Confirm no Analytics / Ledgers / Payments tab introduced via this work; confirm no UUID strings.

## Relevant Files

- `billing.md` (§§17–19)
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_price_book_panel.dart` (or equivalent price panel)
- `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`
- `frontend/test/features/billing/presentation/billing_access_test.dart`
- `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`
