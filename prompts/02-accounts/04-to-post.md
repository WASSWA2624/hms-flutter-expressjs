# Accounts — To post

## Context

Implement the **To post** desk section (`?section=journals`) on `/accounts` per `accounts.md`. This queue lists draft / unposted journals only, ready to post to the books. Source of truth: root `accounts.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the To post tab with label **To post** and tooltip: *Draft journal entries ready to post to the books*.
2. Persist and write URL `/accounts?section=journals` (accept aliases `journal-entries`, `unposted`, `ready-to-post`, `?tab=journals`).
3. Render shared work-queue chrome: Search · Filters · Table settings · Export · trailing **Post all** only when the user has `accounts:write`.
4. Default columns (≤5): Journal · Period · Amount · Status · Next. Persist table settings as `accounts_journals_v1`.
5. Search with ~350ms debounce and hint *Account, journal, reference…*. Filters use shared groups with status choices scoped to drafts on this tab only.
6. Show empty copy *No drafts to post.* when empty; show loading, error, and success (snackbar) states.
7. Row Next is **Post** when authorized; omit when unauthorized. Happy path: Next → Post modal (optional notes) → save → snackbar → refresh. Do not require Detail first.
8. Trailing **Post all** confirms then bulk-posts the selection or current page when write-authorized; refresh list and strip count afterward.
9. Row click opens shared Detail; secondary actions include Reverse, Void, Send, GL, Print when capable.
10. **Print** opens shared print preview with comprehensive journal section options and a well-laid-out printout (`accounts.md` §17); never print silently.
11. Draft journal **updates** (edit lines before post) run similarity review excluding self (`accounts.md` §18).
12. Deep link `?section=journals&action=post` (and optional friendly `id`) opens the Post modal after load when authorized.
13. Gate with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Write / Post / Post all require `accounts:write`. Omit unauthorized controls; no disabled “no access” chrome.
14. Keep count tone **warning**. Enable realtime + light poll while active.
15. After post mutations, remove or update rows that leave the draft queue and synchronize strip counts.
16. Never display raw UUIDs — use journal numbers, account codes, period labels (`accounts.md` §19).

## Constraints

- Show draft journals only; do not mix approval / period / patient-ledger rows into this tab.
- Do not put Journal, Open period, Close period, or Add as trailing on this tab.
- Do not require Detail before Post.
- Do not skip print preview or draft-update similarity review.
- Reuse Accounts workspace page, controller, access gates, shared table support, Detail shell, Post modal, `AppPrintPreviewWorkspace`, and `AppSimilarity*` patterns.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: To post is visible with the specified label and tooltip when authorized. (R1, R11)
- [ ] AC2: `/accounts?section=journals` and aliases select To post and write `section=journals`. (R2)
- [ ] AC3: Search bar order includes trailing **Post all** only with `accounts:write`; settings key `accounts_journals_v1`. (R3, R4, R11)
- [ ] AC4: Default columns are Journal · Period · Amount · Status · Next (≤5). (R4)
- [ ] AC5: Empty state shows *No drafts to post.*; loading and error states are visible. (R6)
- [ ] AC6: Authorized Next **Post** completes in one modal → save → snackbar → refresh without Detail. (R7, R13)
- [ ] AC7: Unauthorized Post / Post all are absent (not disabled). (R7, R8, R11)
- [ ] AC8: Post all bulk-posts selection or page and refreshes counts. (R8, R13)
- [ ] AC9: Row click opens shared Detail with capable secondary actions. (R9)
- [ ] AC10: Print opens preview with section toggles; printout is branded and well laid out; no silent print. (R10)
- [ ] AC11: Draft journal updates run similarity review when matches exist. (R11)
- [ ] AC12: No raw UUIDs appear in To post UI, Detail, or print. (R16)
- [ ] AC13: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: Post / Post all absent without `accounts:write`; present when write applies.
- Flow tests: Post from Next; Post all; Print → preview; list membership updates; `action=post` deep link.
- Manual check: empty/loading/error, print layout, viewports, themes.
- Confirm only drafts appear on this tab; confirm no UUID strings in UI/print.

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
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/features/accounts/presentation/accounts_workspace_page_test.dart`
- `frontend/test/features/accounts/presentation/accounts_to_post_permissions_test.dart`
