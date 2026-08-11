# Claims — Settled

## Context

Implement the **Settled** desk section (`?section=settled`) on `/claims` per `claims.md`. This is a review-only queue of paid and cancelled claims. Remittance already posted on Active claims / Billing reconcile — Settled must not collect cash or re-post receipts. Source of truth: root `claims.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Settled tab with label **Settled** (≤2 words) and tooltip: *Paid and cancelled claims for review only*.
2. Persist and write URL `/claims?section=settled` (accept aliases `paid`, `closed`, `?tab=settled`).
3. Render shared work-queue chrome in order: Search · Filters · Table settings · Export. Trailing actions: none.
4. Default columns (≤5): Reference · Patient · Coverage · Settlement · Status. Optional via settings: Invoice · Amount · Updated. Persist as `claims_settled_v1`.
5. Search with ~350ms debounce and hint *Search reference, coverage, invoice, or patient*. Advanced Filters: Paid · Cancelled (tab-scoped only).
6. Show empty copy *No settled claims.* when empty; show loading, error, and success (snackbar) states for load/export.
7. Do **not** mount Next, Prepare, Request, Sync, Submit, Respond, or Close on this tab.
8. Gate the tab with `billing:read` ∩ `insurance-claims`. Row click opens shared Detail (claim kind) with billing-impact read panel.
9. Detail **Print** / export requires (`reports:read` ∪ `evidence:export`) ∩ `insurance-claims`. Omit when unauthorized.
10. **Print** opens shared print preview with claim statement section options (`claims.md` §17); never print silently.
11. Keep count tone **info**. Enable realtime + light poll while active.
12. Never display raw UUIDs — use claim references, patient name/MRN, coverage codes, invoice numbers (`claims.md` §19).

## Constraints

- Do not mount mutate / Sync / Prepare / Close / Collect on Settled.
- Do not re-post remittance or invent a local cashier.
- Do not skip print-preview for Print.
- Reuse Claims workspace page, controller, `claims_access`, Detail shell, and `AppPrintPreviewWorkspace` patterns.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Settled is visible with the specified label and tooltip when claims read ∩ `insurance-claims` allow it. (R1, R8)
- [ ] AC2: `/claims?section=settled` and aliases select Settled and write `section=settled`. (R2)
- [ ] AC3: Search bar order is Search · Filters · Table settings · Export; no trailing actions; no Next column. (R3, R7)
- [ ] AC4: Default columns are Reference · Patient · Coverage · Settlement · Status; settings key `claims_settled_v1`. (R4)
- [ ] AC5: Empty state shows *No settled claims.*; loading and error states are visible. (R6)
- [ ] AC6: Prepare / Sync / Close / Collect are absent from Settled UI. (R7)
- [ ] AC7: Print/export absent without nested export ∪; present when authorized. (R9)
- [ ] AC8: Print opens preview with section toggles; no silent print. (R10)
- [ ] AC9: No raw UUIDs appear in Settled UI, Detail, or print. (R12)
- [ ] AC10: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: tab present with read ∩ insurance; Print absent without export ∪; mutate atoms never mount.
- Flow tests: row → Detail; Print → preview; Paid/Cancelled filters.
- Manual check: empty/loading/error, optional columns, print layout, viewports, themes.
- Confirm no UUID strings in UI/print.

## Relevant Files

- `claims.md` (§§17–19)
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
- `frontend/lib/features/claims/domain/entities/claims_settled_financial_inventory.dart`
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/test/features/claims/presentation/claims_settled_permissions_test.dart`
- `frontend/test/features/claims/presentation/claims_settled_billing_sections_scan_test.dart`
- `frontend/test/features/claims/presentation/claims_workspace_page_test.dart`
