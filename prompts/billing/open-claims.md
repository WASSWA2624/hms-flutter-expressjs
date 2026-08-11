# Billing — Open claims

## Context

Implement the **Open claims** desk section (`?section=claims`) on `/billing` per `billing.md`. This queue lists insurance claims and pre-authorizations awaiting action. It requires the `insurance-claims` module in addition to billing access. Source of truth: root `billing.md` §§2–8, 9–11.

## Requirements

1. Show the Open claims tab with label **Open claims** and tooltip: *Insurance claims and pre-authorizations awaiting action*.
2. Persist and write URL `/billing?section=claims` (accept aliases `claims-pending`, `?tab=claims`).
3. Gate tab visibility with billing workspace read/write ∩ `billing-payments` ∩ `insurance-claims`. When unauthorized for claims, omit the tab entirely (fallback remains Open work).
4. Render shared work-queue chrome: Search · Filters · Table settings · Export. Trailing actions: none.
5. Default columns (≤5): Patient · Invoice · Encounter · Status · Next. Optional via settings: Insurer · Scheme · Patient share · Insurer share. Persist as `billing_claims_v1`.
6. Search with ~350ms debounce and hint *Patient, invoice, encounter…*. Filters use shared groups with status choices scoped to open claims / pre-auth on this tab only.
7. Show empty copy *No open claims.* when empty; show loading, error, and success (snackbar) states.
8. Row Next is **Submit**, **Settle**, or **Auth** by row kind when authorized; omit when unauthorized. Happy path: Next → matching modal → save → snackbar → refresh. Do not require Detail first.
9. Claim mutations require `billing:write` ∩ `insurance-claims`. Omit unauthorized Next / Detail claim actions; no disabled “no access” chrome.
10. Row click opens shared Detail (claim / pre-auth kind) with capable secondary actions.
11. Keep count tone **warning**. Enable realtime + light poll while active.
12. After claim mutations, synchronize list membership and strip counts.

## Constraints

- Do not show Open claims without `insurance-claims`.
- Do not add trailing Charge / Pay / Close / Issue all on this tab.
- Do not reimplement a separate Claims workspace tab inside Billing beyond this section.
- Reuse Billing workspace page, controller, claims access requirements, Detail shell, and claim form dialogs.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Open claims is visible with the specified label and tooltip only when billing ∩ `insurance-claims` allow it. (R1, R3)
- [ ] AC2: Without `insurance-claims`, the Open claims tab is absent and the user can still use other authorized Billing tabs. (R3)
- [ ] AC3: `/billing?section=claims` and alias `claims-pending` select Open claims and write `section=claims` when allowed. (R2)
- [ ] AC4: Default columns are Patient · Invoice · Encounter · Status · Next; settings key `billing_claims_v1`; no trailing actions. (R4, R5)
- [ ] AC5: Empty state shows *No open claims.*; loading and error states are visible. (R7)
- [ ] AC6: Authorized Next Submit / Settle / Auth completes in one modal → save → snackbar → refresh without Detail. (R8, R12)
- [ ] AC7: Unauthorized claim actions are absent (not disabled). (R9)
- [ ] AC8: Row click opens shared Detail for claim / pre-auth. (R10)
- [ ] AC9: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R4)

## Verification

- Permissions tests: tab absent without `insurance-claims`; present with billing read + insurance module; mutations absent without write ∩ insurance.
- Flow tests: Submit, Settle, and Auth happy paths refresh the queue.
- Manual check: empty/loading/error, optional columns via settings, viewports, themes.
- Confirm no trailing actions on this tab.

## Relevant Files

- `billing.md`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_detail_widgets.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`
- `frontend/lib/features/billing/domain/entities/billing_claims_pending_financial_inventory.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/test/features/billing/presentation/billing_claims_pending_permissions_test.dart`
- `frontend/test/features/billing/presentation/billing_claims_pending_billing_sections_scan_test.dart`
- `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`
