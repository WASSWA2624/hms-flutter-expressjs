# Accounts — Close books

## Context

Implement the **Close books** desk section (`?section=books`) on `/accounts` per `accounts.md`. This is fiscal periods: open, review checklist, and close — not a journal reprint. Source of truth: root `accounts.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Close books tab with label **Close books** and tooltip: *Fiscal periods: open, review checklist, and close*.
2. Persist and write URL `/accounts?section=books` (accept aliases `periods`, `period-close`, `close`, `?tab=books`).
3. Render search-bar chrome: Search · Filters · Table settings · Export · trailing **Open period** and **Close period** only when the user has `accounts:write`.
4. Default columns (≤5): Period · Status · Opened · Closed · Next. Optional via settings: Facility · By. Persist as `accounts_books_v1`.
5. Search with ~350ms debounce. Filters are tab-local and include **Open** chip and **Overdue close** chip (danger count tone on the chip, not a separate tab).
6. Show empty copy *No periods match.* when empty; show loading, error, and success (snackbar) states.
7. Resolve one Next per row: Open → **Close** · Pending approval → **Approve** · else → **Books**. Omit Next when unauthorized.
8. **Close** opens Close period modal (checklist context: unposted count · pending approvals · Notes · Submit for approval). Primary: **Close**. Require `accounts:write`. Period close that needs approval uses `accounts:write` ∩ `financial:approve` for Approve.
9. Trailing **Open period** opens Open period modal (Label / dates · Notes). Primary: **Open**. **Before save**, run similarity review against existing periods (label, overlapping dates) (`accounts.md` §18). Trailing **Close period** opens Close period modal for the selected/context period.
10. Row click opens shared Detail (Books kind) with checklist: unposted journals, trial snapshot, approvals, and link to unposted To post filter.
11. Books Detail **Print** opens shared print preview with period/checklist section options and a well-laid-out printout (`accounts.md` §17); never print silently. (Fiscal close is not a journal-reprint tab; period summary print via preview is allowed.)
12. Deep link `?section=books&action=close&id=` opens Close period modal after load. `periodId` opens Books detail or filters Close books (prefer period label / friendly id).
13. Gate with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Open / Close writes require `accounts:write`. Omit unauthorized controls; no disabled “no access” chrome.
14. Keep count tone **warning** for open periods. Enable realtime + light poll while active.
15. After open / close / approve mutations, snackbar (*Submitted for approval.* / *Saved.*) and refresh list + strip counts.
16. Never display raw UUIDs — use period labels and journal numbers (`accounts.md` §19).

## Constraints

- Do not put Open period / Close period outside this tab (single owner).
- Do not put Journal, Post all, or Add as trailing on this tab.
- Do not require Detail before Close / Approve happy paths.
- Do not host Analytics or Trial balance as a separate Accounts tab from this work.
- Do not skip Open period similarity or print preview for Books Print.
- Reuse Accounts workspace page, `accounts_books_panel`, Detail shell, Open / Close dialogs, access gates, `AppPrintPreviewWorkspace`, and `AppSimilarity*` patterns.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Close books is visible with the specified label and tooltip when authorized. (R1, R12)
- [ ] AC2: `/accounts?section=books` and aliases select Close books and write `section=books`. (R2)
- [ ] AC3: Trailing **Open period** / **Close period** appear only with `accounts:write`; settings key `accounts_books_v1`. (R3, R9, R12)
- [ ] AC4: Default columns are Period · Status · Opened · Closed · Next (≤5). (R4)
- [ ] AC5: Empty state shows *No periods match.*; Open and Overdue close filter chips work; overdue uses danger tone on the chip. (R5, R6)
- [ ] AC6: Authorized Next **Close** / **Approve** / **Books** complete without requiring Detail first where applicable. (R7, R8, R14)
- [ ] AC7: Unauthorized Open / Close / Approve are absent (not disabled). (R8, R12)
- [ ] AC8: `action=close&id=` deep link opens Close period modal; row click opens Books detail. (R10, R12)
- [ ] AC9: Open period runs similarity review when matches/overlaps exist. (R9)
- [ ] AC10: Books Print opens preview with section toggles; printout is branded and well laid out; no silent print. (R11)
- [ ] AC11: No raw UUIDs appear in Close books UI, Detail, or print. (R16)
- [ ] AC12: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: Open / Close absent without `accounts:write`; Approve absent without `accounts:write` ∩ `financial:approve`.
- Flow tests: Open period with similarity; Close → submit for approval; Approve from Next; Print → preview; deep links.
- Manual check: empty/loading/error, Open/Overdue chips, print layout, viewports, themes.
- Confirm Open/Close trailing are not duplicated on other Accounts tabs; confirm no UUID strings.

## Relevant Files

- `accounts.md` (§§17–19)
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_books_panel.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_detail_widgets.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_form_dialogs.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_workspace_table_support.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/features/accounts/presentation/accounts_close_books_permissions_test.dart`
- `frontend/test/features/accounts/presentation/accounts_workspace_page_test.dart`
