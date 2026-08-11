# Billing — To issue

## Context

Implement the **To issue** desk section (`?section=issue`) on `/billing` per `billing.md`. This queue lists draft invoices only, ready to issue to the patient or payer. Source of truth: root `billing.md` §§2–8, 9–11.

## Requirements

1. Show the To issue tab with label **To issue** and tooltip: *Draft invoices ready to issue to the patient or payer*.
2. Persist and write URL `/billing?section=issue` (accept aliases `needs-issue`, `ready-to-issue`, `?tab=issue`).
3. Render shared work-queue chrome: Search · Filters · Table settings · Export · trailing **Issue all** only when the user has write access.
4. Default columns (≤5): Patient · Invoice · Encounter · Status · Next. Persist table settings as `billing_issue_v1`.
5. Search with ~350ms debounce and hint *Patient, invoice, encounter…*. Filters use shared groups with status choices scoped to drafts on this tab only.
6. Show empty copy *No drafts to issue.* when empty; show loading, error, and success (snackbar) states.
7. Row Next is **Issue** when authorized; omit when unauthorized. Happy path: Next → Issue modal (optional notes) → save → snackbar → refresh. Do not require Detail first.
8. Trailing **Issue all** confirms then bulk-issues the selection or current page when write-authorized; refresh list and strip count afterward.
9. Row click opens shared Detail; secondary actions include Adjust, Void, Send, Ledger → Accounts, Print when capable.
10. Gate with (`billing:read` ∪ `billing:write`) ∩ `billing-payments`. Write actions require `billing:write`. Omit unauthorized controls; no disabled “no access” chrome.
11. Keep count tone **warning**. Enable realtime + light poll while active.
12. After issue mutations, remove or update rows that leave the draft queue and synchronize strip counts.

## Constraints

- Show draft invoices only; do not mix collect / claims / approval rows into this tab.
- Do not put Charge, Close shift, Close day, or Pay as trailing on this tab.
- Do not host patient ledger UI here; Ledger deep-links to `/accounts?section=ledgers&patientId=`.
- Reuse Billing workspace page, controller, access gates, shared table support, Detail shell, and Issue modal.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: To issue is visible with the specified label and tooltip when authorized. (R1, R10)
- [ ] AC2: `/billing?section=issue` and aliases `needs-issue` / `ready-to-issue` select To issue and write `section=issue`. (R2)
- [ ] AC3: Default columns are Patient · Invoice · Encounter · Status · Next; settings key `billing_issue_v1`. (R4)
- [ ] AC4: Empty state shows *No drafts to issue.*; loading and error states are visible. (R6)
- [ ] AC5: Authorized Next **Issue** completes in one modal → save → snackbar → refresh without Detail. (R7, R12)
- [ ] AC6: **Issue all** appears only with write access; confirms then bulk-issues and refreshes. (R3, R8, R10)
- [ ] AC7: Unauthorized Issue / Issue all / secondary actions are absent (not disabled). (R7, R10)
- [ ] AC8: Row click opens Detail with secondary Adjust / Void / Send / Ledger / Print when capable. (R9)
- [ ] AC9: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: tab visible with read; Issue / Issue all absent without write.
- Flow test: single Issue and Issue all update list membership and counts.
- Manual check: empty/loading/error, search/filters, table settings, viewports, themes.
- Confirm only drafts appear in the queue.

## Relevant Files

- `billing.md`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_detail_widgets.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`
- `frontend/lib/features/billing/domain/entities/billing_needs_issue_financial_inventory.dart`
- `frontend/test/features/billing/presentation/billing_needs_issue_permissions_test.dart`
- `frontend/test/features/billing/presentation/billing_needs_issue_billing_sections_scan_test.dart`
- `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`
