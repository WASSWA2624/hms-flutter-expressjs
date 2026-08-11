# Billing — Open work

## Context

Implement the **Open work** desk section (`?section=work`) on `/billing` per `billing.md`. This is the cross-queue list of billing items that still need action (issue, pay, claim, approve, …). It is the fallback tab when other sections are unauthorized. Source of truth: root `billing.md` §§2–8, 9–11.

## Requirements

1. Show the Open work tab with label **Open work** (≤2 words) and tooltip: *All billing items that still need action across issue, collect, claims, and approvals*.
2. Persist and write URL `/billing?section=work` (accept aliases `all`, `inbox`, `?tab=work`).
3. Render the shared work-queue chrome in order: Search · Filters · Table settings · Export · trailing **Charge** only when the user has write access.
4. Default columns (≤5): Patient · Invoice · Due · Status · Next. Persist table settings as `billing_work_v1`.
5. Search with ~350ms debounce and hint *Patient, invoice, encounter…*. Filters use shared groups (Patient · Invoice · Encounter · Source · Status · Issued date) with status choices scoped to this tab only.
6. Show empty copy *No open work.* when the filtered list is empty; show loading, error, and success (snackbar) states for load and mutations.
7. Resolve one Next action per row using priority Approve → Issue → Pay → Submit → Settle → Auth → Refund → Adjust → Void → Send. Omit Next when unauthorized.
8. On Next, open the matching one-step modal, save, snackbar, and refresh the active section without requiring Detail first.
9. On row click, open the shared Billing Detail dialog; secondary actions stay in Detail.
10. Trailing **Charge** opens the Charge modal; on success create a draft and land the user on To issue (`?section=issue`).
11. Gate the tab with (`billing:read` ∪ `billing:write`) ∩ `billing-payments`. Omit unauthorized trailing / Next / Detail actions; do not render disabled “no access” chrome.
12. Keep count tone **info** on the tab strip. Enable realtime + light poll while this section is active.
13. After mutations, synchronize workspace state so the Open work list and strip count update.

## Constraints

- Do not add Payments, Overdue, Ledgers, or Analytics tabs.
- Do not place Close shift, Close day, Issue all, or Pay as trailing on this tab.
- Do not require Detail before Next happy paths.
- Reuse Billing workspace page, controller, access gates, shared table support, Detail shell, and form dialogs; mirror `/hr` chrome.
- Patient ledger opens only via deep-link to Accounts (`/accounts?section=ledgers&patientId=`).
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Open work is visible with the specified label and tooltip when the user has billing workspace access. (R1, R11)
- [ ] AC2: Navigating to `/billing?section=work` (and aliases `all` / `inbox`) selects Open work and writes `section=work`. (R2)
- [ ] AC3: Search bar order is Search · Filters · Table settings · Export · Charge (Charge omitted without write). (R3, R11)
- [ ] AC4: Default columns are Patient · Invoice · Due · Status · Next (≤5); settings key `billing_work_v1`. (R4)
- [ ] AC5: Empty state shows *No open work.*; loading and error states are visible. (R6)
- [ ] AC6: Authorized Next opens one modal → save → snackbar → list refresh without opening Detail first. (R7, R8, R13)
- [ ] AC7: Unauthorized Next / Charge / Detail actions are absent (not disabled). (R7, R11)
- [ ] AC8: Charge creates a draft and navigates to To issue. (R10, R13)
- [ ] AC9: Row click opens shared Detail; secondary actions are available from Detail only. (R9)
- [ ] AC10: Layout remains usable on mobile, tablet, and desktop in light and dark themes without clipping or inaccessible actions. (R3)

## Verification

- Widget / permissions tests for Open work tab visibility, Charge omission without `billing:write`, and Next omission when unauthorized.
- Flow test: Charge → draft → lands on To issue; Next Pay/Issue path without Detail.
- Manual check: strip count tone, empty/loading/error, search debounce, table settings persistence, light + dark, narrow viewport.
- Confirm no Payments / Overdue / Ledgers / Analytics tab appears.

## Relevant Files

- `billing.md`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_detail_widgets.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_quick_charge_dialog.dart` (or Charge dialog equivalent)
- `frontend/test/features/billing/presentation/billing_access_test.dart`
- `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`
- `frontend/test/features/billing/presentation/billing_all_permissions_test.dart`
