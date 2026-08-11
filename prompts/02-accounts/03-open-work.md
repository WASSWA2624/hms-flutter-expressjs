# Accounts — Open work

## Context

Implement the **Open work** desk section (`?section=work`) on `/accounts` per `accounts.md`. This is the cross-queue list of accounting items that still need action across journals, approvals, and period tasks. It is the fallback tab when other sections are unauthorized. Billing handoffs appear as **Source = Billing**, not as a separate tab. Source of truth: root `accounts.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Open work tab with label **Open work** (≤2 words) and tooltip: *All accounting items that still need action across journals, approvals, and period tasks*.
2. Persist and write URL `/accounts?section=work` (accept aliases `all`, `inbox`, `?tab=work`).
3. Render the shared work-queue chrome in order: Search · Filters · Table settings · Export · trailing **Journal** only when the user has `accounts:write`.
4. Default columns (≤5): Journal · Source · Amount · Status · Next. Persist table settings as `accounts_work_v1`.
5. Search with ~350ms debounce and hint *Account, journal, reference…*. Filters use shared groups (Account · Journal · Source · Status · Period · Posted date) with status choices scoped to this tab only.
6. Show empty copy *No open work.* when the filtered list is empty; show loading, error, and success (snackbar) states for load and mutations.
7. Resolve one Next action per row using priority Approve → Post → Reverse → Void → Close → GL → Ledger. Omit Next when unauthorized.
8. On Next, open the matching one-step modal, save, snackbar, and refresh the active section without requiring Detail first.
9. On row click, open the shared Accounts Detail dialog; secondary actions stay in Detail.
10. Trailing **Journal** opens the Journal create modal; **before save** run similarity review against near-duplicate draft journals (period · source · line accounts · amounts) per `accounts.md` §18; on success create a draft and land the user on To post (`?section=journals`).
11. Gate the tab with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Omit unauthorized trailing / Next / Detail actions; do not render disabled “no access” chrome.
12. Keep count tone **info** on the tab strip. Enable realtime + light poll while this section is active.
13. After mutations, synchronize workspace state so the Open work list and strip count update.
14. Detail **Print** opens shared print preview with comprehensive journal section options and a well-laid-out printout (`accounts.md` §17); never print silently.
15. Never display raw UUIDs in the table, Detail, Journal dialog, similarity UI, snackbars, or printout — use journal numbers, account codes, period labels (`accounts.md` §19).

## Constraints

- Do not add Analytics, Billing cashier, Postings, or Trial balance tabs.
- Do not place Post all, Open period, Close period, or Add as trailing on this tab.
- Do not require Detail before Next happy paths.
- Do not skip Journal similarity review or print-preview for Print.
- Reuse Accounts workspace page, controller, access gates, shared table support, Detail shell, form dialogs, `AppPrintPreviewWorkspace`, and `AppSimilarity*` patterns; mirror `/hr` and `/billing` chrome.
- Pay deep-links only to Billing Collect due; Charge stays on Billing.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Open work is visible with the specified label and tooltip when the user has accounts workspace access. (R1, R11)
- [ ] AC2: Navigating to `/accounts?section=work` (and aliases `all` / `inbox`) selects Open work and writes `section=work`. (R2)
- [ ] AC3: Search bar order is Search · Filters · Table settings · Export · Journal (Journal omitted without `accounts:write`). (R3, R11)
- [ ] AC4: Default columns are Journal · Source · Amount · Status · Next (≤5); settings key `accounts_work_v1`. (R4)
- [ ] AC5: Empty state shows *No open work.*; loading and error states are visible. (R6)
- [ ] AC6: Authorized Next opens one modal → save → snackbar → list refresh without opening Detail first. (R7, R8, R13)
- [ ] AC7: Unauthorized Next / Journal / Detail actions are absent (not disabled). (R7, R11)
- [ ] AC8: Journal runs similarity review when matches exist, then creates a draft and navigates to To post. (R10, R13, R14)
- [ ] AC9: Row click opens shared Detail; secondary actions are available from Detail only. (R9)
- [ ] AC10: Detail Print opens preview with section toggles; printout is branded and well laid out; no silent print. (R14)
- [ ] AC11: No raw UUIDs appear in Open work UI, Journal, similarity, or print. (R15)
- [ ] AC12: Layout remains usable on mobile, tablet, and desktop in light and dark themes without clipping or inaccessible actions. (R3)

## Verification

- Widget / permissions tests for Open work tab visibility, Journal omission without `accounts:write`, and Next omission when unauthorized.
- Flow test: Journal → similarity (when matches) → draft → lands on To post; Next Post/Approve path without Detail; Print → preview.
- Manual check: strip count tone, empty/loading/error, search debounce, table settings persistence, print layout, light + dark, narrow viewport.
- Confirm no Analytics / Billing cashier / Trial balance tab appears; confirm no UUID strings in UI/print.

## Relevant Files

- `accounts.md` (§§17–19)
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_workspace_table_support.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_detail_widgets.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_form_dialogs.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_journal_dialog.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/features/accounts/presentation/accounts_workspace_page_test.dart`
- `frontend/test/features/accounts/presentation/accounts_all_permissions_test.dart`
