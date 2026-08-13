# Accounts — replace Close books with Invoices

## Context

### Current implementation (baseline)

Accounts workspace at `/accounts` (screenshot: `prompts/image/accounts/1786611991553.png`, live URL `?section=chart`) uses nested `AppTabStrip` desks with live counts:

| Tab (UI) | `AccountsDeskSection` | `?section=` |
| --- | --- | --- |
| Open work | `work` | `work` |
| To post | `journals` | `journals` |
| Need approval | `approvals` | `approvals` |
| General ledger | `gl` | `gl` |
| Patient ledgers | `ledgers` | `ledgers` |
| Account chart | `chart` | `chart` |
| **Close books** | **`books`** | **`books`** (+ aliases `periods` / `period-close` / `close`) |

Account chart (and sibling list desks) already ship the target chrome: `AppSearchBar` + Filters → Settings → Export → Print → primary create (`+ Add`), empty/loading/error states, RBAC omission, print/export via evidence-export, mutations via maximized `AppDialog`s. Close books is implemented as `AccountsBooksPanel` plus period open/close/approve dialogs, similarity helpers, print options, summary `openPeriods`, and books Next-action helpers in `accounts_access.dart`.

Billing already owns **patient** invoices under `/billing`. Accounts has no Invoices desk today.

### Intended behavior (delta only)

1. **Remove** the Close books desk and all Close-books-only code paths.
2. **Add** an **Invoices** desk that lists facility **outflow** invoices (money leaving the facility), with create/detail/edit/print/delete-with-reason — matching existing Accounts list-desk patterns (especially Account chart).
3. **Preserve** Open work, To post, Need approval, General ledger, Patient ledgers, Account chart, and all non-books journal/GL/ledger/chart behavior unless a touch is required for enum/routing/tab-strip glue.

Follow `prompts/.cursor/` (`prompt.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, localization / theming / responsiveness). Reference those files; do not restate them.

## Definitions

- **Accounts invoice** — facility-scoped document for amounts leaving the facility (payee/vendor, line items, totals, status). **Not** a Billing patient/encounter invoice.
- **Line item** — name, description, quantity, unit price; line total and invoice total derived.
- **Delete with reason** — void/cancel that requires a non-empty reason before commit (same pattern as other Accounts destructive mutations).

## Requirements

### A. Preserve existing desks

1. Keep Open work, To post, Need approval, General ledger, Patient ledgers, and Account chart behavior, routes, panels, filters, prints, and permissions unchanged except where Required B–F force shared enum / strip / summary / test updates.
2. Keep GL (and other desks’) existing **period** text/filter fields if they are posting-period labels or list filters — remove only Close-books **desk**, period **open/close/approve** flows, and books-only UI.

### B. Remove Close books

3. Remove the Close books tab from the Accounts strip; stop rendering `AccountsBooksPanel`.
4. Remove `AccountsDeskSection.books` and slug aliases (`books` / `periods` / `period-close` / `close`) as a live desk target.
5. Delete Close-books-only presentation: books panel, books table support, books print helpers/options, period open/close/approve forms and similarity dialogs used only for period close, Close books strings/tooltips/empty copy, and books-only Next-action helpers.
6. Remove workspace summary / count wiring for `openPeriods` / books badges, and frontend repository/DTO methods used solely to list/get/open/close/approve fiscal periods. Do not leave dead UI entry points.
7. Legacy `?section=books` (or former aliases) must resolve to an authorized remaining section via existing `resolveAccountsSection` (prefer Invoices when present and allowed) with **no** Close books flash.
8. Update permission-catalog copy, workspace comments, and tests that still describe period close / Close books as an Accounts desk.

### C. Add Invoices desk

9. Add `AccountsDeskSection.invoices` with slug `invoices` → `/accounts?section=invoices`. Place the tab in the former Close books position (after Account chart).
10. Label the tab **Invoices**. Show an authoritative count badge per `tabs.mdc` (workspace/server total; filtered total when this tab’s search/filters narrow the set).
11. Implement an Invoices panel mirroring Account chart desk chrome: search, Filters, Settings, Export, Print, primary **Create invoice** — omit Export/Print/Create when unauthorized (reuse Accounts export/write gates).
12. Search covers operator identity fields (e.g. number, payee, status). Filters include at least status and date range; use the shared Advanced filters pattern already used on Accounts desks.
13. Cover loading, empty, and error states (empty copy style aligned with Account chart: clear title + short next step). No silent stale table after failed load or filter apply.
14. Table columns must support scanning (at least number/id, payee, date, status, total; row actions when write is allowed). Keep cells short; put full identity in the detail dialog.

### D. Create / edit dialog

15. **Create invoice** opens a maximized `AppDialog` with a generic title (`Create invoice` / `Edit invoice` — no instance id in the title).
16. Capture payee (or vendor), invoice date, optional reference/notes, and currency consistent with existing facility defaults when available.
17. Support add/remove line items: item name, description, quantity, unit price; show derived line totals and grand total. Block save on missing required fields or invalid amounts.
18. On successful save, refresh the Invoices table and tab/summary counts and show existing success/error feedback.
19. Offer Edit only when status allows mutation and the user has Accounts write; omit otherwise.

### E. Detail, print, delete

20. Row activation opens **Invoice details** (generic title) with header, lines, totals, and status.
21. From details and/or row actions, authorized users get **Print**, **Edit**, and **Delete** (void/cancel). Omit each when unauthorized or status-forbidden.
22. Print follows existing Accounts desk print helpers and `printing.mdc` (same export permission gate as sibling desks).
23. Delete requires a reason; empty reason must not submit. After success, refresh list + counts and close detail if open.

### F. Outflow meaning and optional cross-desk create

24. Persisted Accounts invoices must represent **facility outflow** (payee + amount leaving). Prefer posting/linking through existing Accounts journal/GL mechanisms when that is how facility expenses are already recorded — do not invent a parallel ledger or reuse Billing patient invoice APIs/UI.
25. **Optional enhancement (in scope only if low-cost):** expose **Create invoice** from another Accounts desk’s existing primary/secondary or Next action slot where it fits without clutter (same dialog + permissions as the Invoices tab). Do **not** add Create invoice to every tab by default.

### G. Localization, access, sync

26. Add Invoices strings via l10n (`app_en.arb` + generated localizations). Remove unused Close books strings after deletion.
27. Browse Invoices with existing Accounts entry/read; Create/Edit/Delete with Accounts write; Export/Print with existing evidence-export. Unauthorized controls must not render (no disabled stubs).
28. After invoice mutations, synchronize table rows, visible tab counts, and any workspace summary fields that include invoice counts.

## Constraints

- Reuse Accounts workspace shell, `AppTabStrip`, `AppListTable`, `AppSearchBar`, `AppDialog`, print/export helpers, and `accounts_access.dart` — no parallel chrome.
- Prefer new Accounts invoice entities/DTOs/repository methods over cloning Billing invoice models.
- No drive-by refactors outside Close books removal and Invoices addition (plus required shared glue).
- Backend RBAC/ABAC remains authoritative.
- Required UI states: permission-omit, loading, empty, error, validation, success feedback.

## Out of scope

- Redesigning Billing patient invoices or merging Billing and Accounts invoice products.
- Changing unrelated Accounts queue/GL/ledger/chart workflows beyond books removal glue.
- Rebuilding fiscal-period close as a different UI unless a later prompt asks for it.

## Acceptance Criteria

- [ ] AC1 (Req 1–2): Non-books desks still behave as before aside from shared strip/enum/summary updates.
- [ ] AC2 (Req 3–8): Close books tab and books-only code/tests are gone; `?section=books` does not show Close books.
- [ ] AC3 (Req 9–14): `/accounts?section=invoices` shows Invoices with search, Filters, Settings, Export, Print, Create invoice (when allowed), count badge, and loading/empty/error states.
- [ ] AC4 (Req 15–19): Create/Edit dialog supports payee/meta + line items with validation and post-save refresh.
- [ ] AC5 (Req 20–23): Row opens details; Print / Edit / Delete-with-reason appear only when allowed.
- [ ] AC6 (Req 24–25): Invoices model facility outflow and stay separate from Billing; optional cross-desk create, if implemented, reuses the same dialog.
- [ ] AC7 (Req 26–28): Strings localized; unauthorized UI omitted; mutations refresh list and counts.
- [ ] AC8: Tests updated — books compliance/period-close desk tests removed or rewritten; section resolution, tab presence, access omission, and Invoices smoke covered.

## Verification

- Manual: `/accounts` tab order ends with Account chart → **Invoices** (no Close books). Create an invoice with ≥2 lines; open details; print; edit; delete with reason; confirm empty and filter states.
- Manual: `/accounts?section=books` lands on an allowed section without Close books UI.
- Manual: light/dark and a narrow viewport — strip overflow, toolbar, and dialogs remain usable.
- Tests: Accounts workspace / section / access / convention tests; add Invoices panel or dialog coverage as needed; drop `accounts_books_*` / period-close desk tests that only served Close books.
- Analyze touched frontend paths; run the affected Accounts test files.

## Relevant Files

### Current Close books surface (remove / unlink)

- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_books_panel.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_books_table_support.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_books_print_helpers.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_books_print_options.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_period_dialogs.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_period_similarity.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_period_similarity_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_form_dialogs.dart` (period open/close forms only)
- `frontend/lib/features/accounts/presentation/widgets/accounts_scope_navigation.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_support.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/accounts_strings.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/domain/entities/accounts_entities.dart`
- `frontend/lib/features/accounts/data/dtos/accounts_dtos.dart`
- `frontend/lib/features/accounts/data/repositories/accounts_repository_impl.dart`
- `frontend/lib/features/accounts/domain/repositories/accounts_repository.dart`
- `frontend/test/features/accounts/presentation/accounts_books_compliance_test.dart`
- `frontend/test/features/accounts/presentation/accounts_period_similarity_test.dart`
- `backend/src/config/permission-catalog-metadata.js` (desk copy mentioning period close)
- `backend/src/modules/accounts-workspace/services/accounts-workspace.service.js` (`open_periods*` summary fields)

### Patterns to mirror for Invoices

- `frontend/lib/features/accounts/presentation/widgets/accounts_chart_panel.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_chart_dialogs.dart`
- `frontend/lib/l10n/app_en.arb`
- Accounts API / workspace module — add invoice list/create/update/void only as required

### Reference

- `prompts/image/accounts/1786611991553.png`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
