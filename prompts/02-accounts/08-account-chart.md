# Accounts — Account chart

## Context

Implement the **Account chart** desk section (`?section=chart`) on `/accounts` per `accounts.md`. This is the CRUD table of chart of accounts codes, types, and status. Source of truth: root `accounts.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Account chart tab with label **Account chart** and tooltip: *Chart of accounts codes, types, and status*.
2. Persist and write URL `/accounts?section=chart` (accept aliases `chart-of-accounts`, `coa`, `?tab=chart`).
3. Render search-bar chrome: Search · Filters · Table settings · Export · trailing **Add** only when the user has accounts / admin chart write.
4. Default columns (≤5): Account · Type · Code · Status · Actions. Optional via settings: Parent · Currency · Effective. Persist as `accounts_chart_v1`.
5. Search with debounce appropriate to the shared Accounts table contract. Filters are scoped to chart fields (type, status, parent, currency, effective) — not the journal work-queue status dump.
6. Show empty copy *No accounts match.* when empty; show loading, error, validation, and success (snackbar) states for load and save.
7. Trailing **Add** opens Account create dialog (Code · Name · Type · Parent · Currency · Effective · Active) with primary **Save**.
8. **Before save on create and update**, run similarity review on Code · Name · Type · Parent against existing chart rows (`accounts.md` §18). Exact code match blocks create (offer Select existing); near match offers Select / Overwrite / Continue.
9. Row Actions support Edit / Deactivate when authorized; row click opens the edit dialog. On save (after similarity), snackbar and refresh the table.
10. Optional **Print** of the filtered chart opens shared print preview with section options (`accounts.md` §17); never print silently.
11. Gate tab with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Chart writes use accounts / admin write. Omit unauthorized Add / Edit / Deactivate; no disabled “no access” chrome.
12. Do not show a strip Next-action column for this CRUD table; Actions column owns row mutations.
13. After create / update / deactivate, synchronize chart data used by Journal create and General ledger.
14. Keep the first viewport as strip + table only (no KPI cards). Match `/hr` / `/billing` chrome. Count = active accounts.
15. Never display raw UUIDs — use account codes/names (`accounts.md` §19).

## Constraints

- Do not put Journal, Post all, Open period, or Close period trailing on this tab.
- Do not host Analytics or period close inside Account chart.
- Do not skip similarity on Add/Edit or print preview when printing.
- Reuse Accounts workspace page, `accounts_chart_panel`, access gates, chart Add/Edit dialogs, `AppSimilarity*`, and `AppPrintPreviewWorkspace`.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Account chart is visible with the specified label and tooltip when authorized. (R1, R9)
- [ ] AC2: `/accounts?section=chart` and aliases select Account chart and write `section=chart`. (R2)
- [ ] AC3: Default columns are Account · Type · Code · Status · Actions; settings key `accounts_chart_v1`. (R4)
- [ ] AC4: Empty state shows *No accounts match.*; loading, error, and validation feedback are visible. (R6)
- [ ] AC5: Authorized **Add** runs similarity then creates an account via one dialog → Save → snackbar → refresh. (R3, R7, R8, R13)
- [ ] AC6: Authorized Edit / Deactivate work from Actions or row click; Edit runs similarity; unauthorized variants are absent. (R8, R9, R11)
- [ ] AC7: Without chart write, Add / Edit / Deactivate are absent (not disabled); read-only browse may remain. (R11)
- [ ] AC8: No work-queue Next column and no journal/period trailing actions on this tab. (R3, R12)
- [ ] AC9: Print (when offered) opens preview with section toggles; printout is branded and well laid out. (R10)
- [ ] AC10: No raw UUIDs appear in Account chart UI, similarity, or print. (R15)
- [ ] AC11: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3, R14)

## Verification

- Permissions tests: Add / Edit / Deactivate absent without accounts/admin write; tab readable with accounts access.
- Flow tests: create/edit with similarity; deactivate refresh; Journal create resolves chart accounts after save.
- Manual check: empty/loading/error/validation, optional columns, print layout, viewports, themes.
- Confirm no Analytics / Close books trailing introduced via this work; confirm no UUID strings.

## Relevant Files

- `accounts.md` (§§17–19)
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_chart_panel.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_workspace_table_support.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_form_dialogs.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/features/accounts/presentation/accounts_account_chart_permissions_test.dart`
- `frontend/test/features/accounts/presentation/accounts_workspace_page_test.dart`
