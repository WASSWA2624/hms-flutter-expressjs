# Accounts — General ledger

## Context

Implement the **General ledger** desk section (`?section=gl`) on `/accounts` per `accounts.md`. This is the facility GL by account — balances and activity, not a second journal queue and not patient money. Source of truth: root `accounts.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the General ledger tab with label **General ledger** and tooltip: *Facility account balances and activity by GL account*.
2. Persist and write URL `/accounts?section=gl` (accept aliases `general-ledger`, `ledger`, `?tab=gl`).
3. Render search-bar chrome: Search · Filters · Table settings · Export. Trailing actions: none.
4. Default columns (≤5): Account · Debit · Credit · Balance · Next. Optional via settings: Type · Period · Updated. Persist as `accounts_gl_v1`.
5. Search with ~350ms debounce and hint *Account, journal, reference…*. Filters are scoped to GL account fields (Account · Type · Period · activity), not the journal work-queue status dump.
6. Show empty copy *No accounts match.* when empty; show loading, error, and success (snackbar) states.
7. Row Next is **GL** when the account has activity the user can open; omit otherwise or when unauthorized.
8. Row click and Next **GL** open the shared **Account ledger** dialog (summary Debit · Credit · Balance + entry list). Same dialog as Detail → GL.
9. Inside Account ledger, show **Journal** when the user can create journals (`accounts:write`); do not offer Post (Post stays on To post). Journal create runs similarity review (`accounts.md` §18).
10. Account ledger **Print** opens shared print preview with GL section options and a well-laid-out printout (`accounts.md` §17); never print silently.
11. Deep link `?section=gl&accountId=` opens Account ledger or filters General ledger to that account after load (prefer account code / friendly id).
12. Gate with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Omit unauthorized Next / Journal; no disabled “no access” chrome.
13. Keep count as accounts with activity. Enable realtime + light poll while active.
14. Count tone follows open-period risk only via filter chips elsewhere — this tab is not warning/danger by default.
15. Never display raw UUIDs — use account codes/names and journal numbers (`accounts.md` §19).

## Constraints

- Do not turn General ledger into a journal queue or patient money browse.
- Do not put Journal / Post all / Open period / Close period / Add as trailing on this tab.
- Do not host Analytics or Trial balance as a separate Accounts tab from this work.
- Do not skip print preview or Journal similarity review.
- Reuse Accounts workspace page, `accounts_gl_panel`, shared Account ledger dialog, access gates, `AppPrintPreviewWorkspace`, and `AppSimilarity*` patterns.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: General ledger is visible with the specified label and tooltip when authorized. (R1, R11)
- [ ] AC2: `/accounts?section=gl` and aliases select General ledger and write `section=gl`. (R2)
- [ ] AC3: Default columns are Account · Debit · Credit · Balance · Next; settings key `accounts_gl_v1`; no trailing actions. (R3, R4)
- [ ] AC4: Empty state shows *No accounts match.*; loading and error states are visible. (R6)
- [ ] AC5: Row click / Next **GL** opens the shared Account ledger dialog. (R7, R8)
- [ ] AC6: Account ledger may show Journal when write-authorized (with similarity); Post is absent from this dialog. (R9, R12)
- [ ] AC7: Unauthorized Next / Journal are absent (not disabled). (R7, R12)
- [ ] AC8: `accountId` deep link opens or filters to the account. (R11)
- [ ] AC9: Account ledger Print opens preview with section toggles; printout is branded and well laid out; no silent print. (R10)
- [ ] AC10: No raw UUIDs appear in General ledger UI, Account ledger, or print. (R15)
- [ ] AC11: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: tab readable with accounts access; Journal in GL dialog absent without `accounts:write`.
- Flow tests: row → Account ledger; Next GL; Print → preview; `accountId` deep link.
- Manual check: empty/loading/error, optional columns, print layout, viewports, themes.
- Confirm no patient ledger columns or journal trailing actions on this tab; confirm no UUID strings.

## Relevant Files

- `accounts.md` (§§17–19)
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_gl_panel.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_gl_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_workspace_table_support.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/features/accounts/presentation/accounts_general_ledger_permissions_test.dart`
- `frontend/test/features/accounts/presentation/accounts_workspace_page_test.dart`
