# Billing — Collect due

## Context

Implement the **Collect due** desk section (`?section=collect`) on `/billing` per `billing.md`. This queue lists open balances due for payment (including overdue). Overdue is a filter chip, not a separate tab. Source of truth: root `billing.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Collect due tab with label **Collect due** and tooltip: *Open balances due for payment, including overdue*.
2. Persist and write URL `/billing?section=collect` (accept aliases `awaiting-payment`, `pending-payment`, `overdue`, `?tab=collect`).
3. Render shared work-queue chrome: Search · Filters · Table settings · Export · trailing **Close shift** and **Close day** only when write-authorized.
4. Default columns (≤5): Patient · Invoice · Due · Status · Next. Optional Age via table settings. Persist as `billing_collect_v1`.
5. Search with ~350ms debounce and hint *Patient, invoice, encounter…*. Filters use shared groups plus **Overdue** (Yes/No) and Age. Overdue chip shows danger count tone; do not add an Overdue tab.
6. Show empty copy *No balances due.* when empty; show loading, error, and success (snackbar) states.
7. Row Next is **Pay** when authorized; omit when unauthorized. Happy path: Next → Pay modal (Amount · Method · Reference · Payer · Receipt) → save → snackbar → refresh. Do not require Detail first.
8. When Receipt is on (or user prints after pay), open **print preview** for the receipt with section options (`billing.md` §17); never print the receipt silently.
9. Deep link `?section=collect&action=pay&id=<invoiceId>` opens the Pay modal for that invoice after load (prefer friendly invoice id in the URL when supported).
10. Trailing **Close shift** and **Close day** open their modals (shift: Expected · Actual · Notes · submit for approval; day: Notes · submit for approval); snackbar and refresh afterward.
11. Row click opens shared Detail; secondary actions include Refund, Adjust, Void, Send, Ledger → Accounts, Print when capable.
12. **Print** and receipt print use shared print preview with comprehensive section options and a well-laid-out printout (`billing.md` §17).
13. **Adjust** / refund create-update paths run similarity review when near-duplicate pending requests exist (`billing.md` §18).
14. Gate with (`billing:read` ∪ `billing:write`) ∩ `billing-payments`. Write / close / pay require `billing:write`. Omit unauthorized controls; no disabled “no access” chrome.
15. Keep count tone **warning**. Enable realtime + light poll while active.
16. After pay / close mutations, synchronize list rows and strip counts.
17. Never display raw UUIDs — use invoice numbers, patient name/MRN (`billing.md` §19).

## Constraints

- Do not add a separate Overdue or Payments tab.
- Do not put Charge, Issue all, or Pay as trailing on this tab (Pay is row Next / Detail only).
- Do not place Close shift / Close day on any other Billing tab.
- Do not skip print preview or create/update similarity review.
- Patient ledger is Accounts-only via deep-link.
- Reuse Billing workspace page, controller, access gates, Pay dialog, close-shift/day dialogs, Detail shell, `AppPrintPreviewWorkspace`, and `AppSimilarity*` patterns.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Collect due is visible with the specified label and tooltip when authorized. (R1, R11)
- [ ] AC2: `/billing?section=collect` and aliases (including `overdue`) select Collect due and write `section=collect`. (R2)
- [ ] AC3: Overdue is available as a filter / chip with danger count; no Overdue tab exists. (R5)
- [ ] AC4: Default columns are Patient · Invoice · Due · Status · Next; settings key `billing_collect_v1`. (R4)
- [ ] AC5: Empty state shows *No balances due.*; loading and error states are visible. (R6)
- [ ] AC6: Authorized Next **Pay** completes in one modal → save → snackbar → refresh without Detail. (R7, R13)
- [ ] AC7: `action=pay&id=` opens Pay for the invoice after load. (R8)
- [ ] AC8: Close shift and Close day appear only on this tab with write access; unauthorized variants are absent. (R3, R9, R11)
- [ ] AC9: Row click opens Detail with secondary Refund / Adjust / Void / Send / Ledger / Print when capable. (R11)
- [ ] AC10: Pay receipt and Detail Print open preview with section toggles; printout is branded and well laid out; no silent print. (R8, R12)
- [ ] AC11: Adjust/refund create-update runs similarity review when matches exist. (R13)
- [ ] AC12: No raw UUIDs appear in Collect due UI, Pay, Detail, or print. (R17)
- [ ] AC13: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: Pay / Close shift / Close day absent without `billing:write`.
- Flow tests: Pay happy path; receipt print preview; deep-link `action=pay`; close shift / close day submit for approval copy.
- Manual check: Overdue chip danger tone, empty/loading/error, filters, print layout, viewports, themes.
- Confirm no Overdue or Payments tab in the strip; confirm no UUID strings in UI/print.

## Relevant Files

- `billing.md` (§§17–19)
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_receive_payment_dialog.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_detail_widgets.dart`
- `frontend/lib/features/billing/domain/entities/billing_awaiting_payment_financial_inventory.dart`
- `frontend/lib/features/billing/domain/entities/billing_overdue_financial_inventory.dart`
- `frontend/test/features/billing/presentation/billing_awaiting_payment_permissions_test.dart`
- `frontend/test/features/billing/presentation/billing_overdue_permissions_test.dart`
- `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`
