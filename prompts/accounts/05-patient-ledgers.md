# Accounts — Patient ledgers

## Context

Implement the **Patient ledgers** desk section (`?section=ledgers`) on `/accounts` per `accounts.md`. This is the patient money browse — invoiced, paid, and outstanding balances. It is not an invoice queue and not facility GL. Charge and collect stay on Billing; Pay deep-links to Billing Collect due. Source of truth: root `accounts.md` §§2–8, 9–11.

## Requirements

1. Show the Patient ledgers tab with label **Patient ledgers** and tooltip: *Patient invoiced, paid, and outstanding balances*.
2. Persist and write URL `/accounts?section=ledgers` (accept aliases `patient-ledgers`, `?tab=ledgers`).
3. Render search-bar chrome: Search · Filters · Table settings · Export. Trailing actions: none.
4. Default columns (≤5): Patient · Invoiced · Paid · Balance · Next. Optional via settings: Clearance · Updated. Persist as `accounts_ledgers_v1`.
5. Search with ~350ms debounce. Filters are tab-local (patient / clearance), not the journal work-queue dump.
6. Show empty copy *No patients match.* when empty; show loading, error, and success (snackbar) states.
7. Resolve one Next per row: if balance → **Pay** when (`billing:write`) ∩ `billing-payments`; else → **Ledger** when `accounts:read`. Omit Next when unauthorized.
8. **Pay** deep-links to `/billing?section=collect&action=pay&patientId=` — do not open a collect UI inside Accounts.
9. Row click and Next **Ledger** open the shared **Patient ledger** dialog (summary Invoiced · Paid · Balance + entry list). Same dialog as Detail → Ledger.
10. Inside Patient ledger, show **Pay** when balance and billing write apply; do not offer Charge (Charge stays on Billing Open work).
11. Deep link `?section=ledgers&patientId=` opens the patient ledger dialog after load.
12. Gate tab with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Patient ledgers read requires `accounts:read`. Omit unauthorized Pay / Ledger; no disabled “no access” chrome.
13. Keep count as patients with balance. Enable realtime + light poll while active.

## Constraints

- Do not host Collect due, Charge, invoices, or claims UI on this tab.
- Do not put Journal / Post all / Open period / Close period / Add as trailing on this tab.
- Do not confuse Patient ledgers with General ledger.
- Reuse Accounts workspace page, `accounts_ledgers_panel`, shared Patient ledger dialog, and access gates.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Patient ledgers is visible with the specified label and tooltip when authorized. (R1, R12)
- [ ] AC2: `/accounts?section=ledgers` and alias `patient-ledgers` select Patient ledgers and write `section=ledgers`. (R2)
- [ ] AC3: Default columns are Patient · Invoiced · Paid · Balance · Next; settings key `accounts_ledgers_v1`; no trailing actions. (R3, R4)
- [ ] AC4: Empty state shows *No patients match.*; loading and error states are visible. (R6)
- [ ] AC5: Balance → authorized **Pay** navigates to Billing Collect due; unauthorized Pay is absent. (R7, R8, R12)
- [ ] AC6: Row click / Next **Ledger** opens the shared Patient ledger dialog. (R9)
- [ ] AC7: Patient ledger may show Pay when balance + billing write; Charge is absent. (R10, R12)
- [ ] AC8: `patientId` deep link opens the patient ledger dialog. (R11)
- [ ] AC9: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: tab requires accounts access; Pay absent without billing write ∩ `billing-payments`; Ledger present with `accounts:read`.
- Flow tests: Pay deep-link target; Ledger dialog; `patientId` deep link.
- Manual check: empty/loading/error, clearance filter, viewports, themes.
- Confirm no Charge / Collect due UI inside Accounts.

## Relevant Files

- `accounts.md`
- `billing.md` (Pay target only)
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_ledgers_panel.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_patient_ledger_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_workspace_table_support.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/features/accounts/presentation/accounts_patient_ledgers_permissions_test.dart`
- `frontend/test/features/accounts/presentation/accounts_workspace_page_test.dart`
