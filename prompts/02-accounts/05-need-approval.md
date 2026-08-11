# Accounts — Need approval

## Context

Implement the **Need approval** desk section (`?section=approvals`) on `/accounts` per `accounts.md`. This queue lists journal posts, voids, reversals, and period close awaiting approval. Source of truth: root `accounts.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Need approval tab with label **Need approval** and tooltip: *Journal posts, voids, reversals, and period close awaiting approval*.
2. Persist and write URL `/accounts?section=approvals` (accept aliases `approval-required`, `?tab=approvals`).
3. Render shared work-queue chrome: Search · Filters · Table settings · Export. Trailing actions: none.
4. Default columns (≤5): Journal · Amount · Status · Next. Optional via settings: Type · By · Reason · Period. Persist as `accounts_approvals_v1`.
5. Search with ~350ms debounce and hint *Account, journal, reference…*. Filters use shared groups with status / type choices scoped to pending approval rows on this tab only.
6. Show empty copy *No pending approvals.* when empty; show loading, error, and success (snackbar) states.
7. Row Next is **Approve** when the user has `accounts:write` ∩ `financial:approve`; omit when unauthorized. Happy path: Next → Approve modal → save → snackbar → refresh. Do not require Detail first.
8. **Reject** is available only inside Detail (not as row Next). Omit Reject when unauthorized.
9. Row click opens shared Detail (approval kind) with capable secondary actions including **Print** when authorized.
10. **Print** opens shared print preview with approval-packet section options and a well-laid-out printout (`accounts.md` §17); never print silently.
11. Gate tab with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Omit unauthorized Approve / Reject; no disabled “no access” chrome.
12. Keep count tone **warning**. Enable realtime + light poll while active.
13. After approve / reject mutations, remove or update rows and synchronize strip counts.
14. Never display raw UUIDs — use journal numbers, period labels, request labels (`accounts.md` §19).

## Constraints

- Do not put Approve / Reject as trailing strip actions.
- Do not put Journal, Post all, Open period, Close period, or Add on this tab.
- Do not require Detail before Approve.
- Do not skip print preview for Print.
- Reuse Accounts workspace page, controller, approval access requirement, Detail shell, Approve / Reject dialogs, and `AppPrintPreviewWorkspace`.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Need approval is visible with the specified label and tooltip when authorized. (R1, R10)
- [ ] AC2: `/accounts?section=approvals` and alias `approval-required` select Need approval and write `section=approvals`. (R2)
- [ ] AC3: Default columns are Journal · Amount · Status · Next; settings key `accounts_approvals_v1`; no trailing actions. (R3, R4)
- [ ] AC4: Empty state shows *No pending approvals.*; loading and error states are visible. (R6)
- [ ] AC5: Authorized Next **Approve** completes in one modal → save → snackbar → refresh without Detail. (R7, R12)
- [ ] AC6: Reject appears only in Detail and only when `accounts:write` ∩ `financial:approve`. (R8, R10)
- [ ] AC7: Without approve permission, Approve / Reject are absent (not disabled); tab may still be readable. (R7, R10)
- [ ] AC8: Row click opens shared Detail for the approval request. (R9)
- [ ] AC9: Print opens preview with section toggles; printout is branded and well laid out; no silent print. (R10)
- [ ] AC10: No raw UUIDs appear in Need approval UI, Detail, or print. (R14)
- [ ] AC11: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: Approve / Reject absent without `financial:approve` ∩ `accounts:write`; present when both apply.
- Flow tests: Approve from Next; Reject from Detail; list membership updates; Print → preview.
- Manual check: empty/loading/error, optional Type/By/Reason/Period columns, print layout, viewports, themes.
- Confirm no trailing actions on this tab; confirm no UUID strings in UI/print.

## Relevant Files

- `accounts.md` (§§17–19)
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_workspace_table_support.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_detail_widgets.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_form_dialogs.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/features/accounts/presentation/accounts_need_approval_permissions_test.dart`
- `frontend/test/features/accounts/presentation/accounts_workspace_page_test.dart`
