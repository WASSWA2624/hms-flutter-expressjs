# Prompt 084 — Implement Claim Batches

## Context

- **Sequence:** 084 of 159
- **Phase:** Insurance and claims — claims and settlement
- **Prerequisite:** Prompt 083 — Claim Validations (`prompts/01-finance-tabs/05-insurance-and-claims/03-claims-and-settlement/083-claim-validations.md`).
- **Menu path:** `Insurance & Claims → Claim Batches`
- **Canonical route:** `/claims?section=claim-batches`
- **Tab profile:** `transaction` table/worklist
- **Authoritative tab specification:** `.cursor/finance/insurance-and-claims/claim-batches.md`
- **Finance source of truth:** `.cursor/billing-accounts-finance.md`

Implement this prompt only after the prerequisite prompt passes its acceptance criteria. Treat the tab specification as authoritative for domain behavior, columns, API operations, statuses, permissions, buttons, forms, nested detail tables, and acceptance criteria.

## Requirements

1. **Register and scope the tab.**
   - Implement the `Claim Batches` tab at `Insurance & Claims → Claim Batches` with canonical section slug `claim-batches`.
   - Preserve compatible existing deep-link aliases, but generate new links only with the canonical slug.
   - Reopening the route must focus the existing tab and restore committed search, filters, sorting, pagination, and column settings.
   - Keep the Insurance & Claims menu as one flat workspace whose permanent tabs share the same route.

2. **Implement the backend and data contract.**
   - Implement every list, detail, CRUD, workflow, report, or reconciliation operation defined under **Target API contract** in `.cursor/finance/insurance-and-claims/claim-batches.md`.
   - Extend the existing workspace route/service/repository rather than creating a parallel API.
   - Use Zod validation, `snake_case` JSON, public `human_friendly_id`, paginated `data` plus `meta`, optimistic versions, idempotency for financial mutations, and database transactions.
   - Enforce status transitions, period locks, source-document integrity, and audit logging server-side.

3. **Build the primary table with the exact source columns.**
   - Use `AppListTable`; do not create custom table chrome.
   - Preserve this source order in Settings/export while applying the default/optional visibility defined in `.cursor/finance/insurance-and-claims/claim-batches.md`:
     `Batch No.`, `Batch Date`, `Payer`, `Plan/Contract`, `Facility`, `Claim Count`, `Submitted Amount`, `Currency`, `Service Period From`, `Service Period To`, `Submission Channel`, `Submission File`, `External Batch Reference`, `Accepted Count`, `Rejected Count`, `Prepared By`, `Batch Status`.
   - Implement server sort keys, atomic cells, localized formatting, status badges, monetary alignment/precision, server-filtered totals, a mobile item builder, horizontal overflow, pinned footer, and empty-row padding.

4. **Implement filters and table controls.**
   - Implement these domain filters in addition to comprehensive field filters from the specification: `Search`, `Status`, `Date/period`, `Facility`, `Party`, `Currency`, `Amount range`, `Owner / assigned user`.
   - Follow `prompts/.cursor/tables.mdc` for Search and the standard Filters → Settings → Export → Print toolbar sequence.
   - Use one committed query model for tab count, table rows, Advanced filters, export, print, URL restoration, and saved views.
   - Implement these context-specific toolbar buttons:
     - **Create batch:** gate `billing:write` ∩ `insurance-claims`; enable when validated claims selected; Groups claims for submission.

5. **Implement row actions, bulk actions, and CRUD.**
   - Row buttons:
     - **View:** gate `claims:read` ∩ `insurance-claims`; enable when always; Opens a detail `AppDialog` using the human-friendly reference.
     - **Edit draft:** gate `billing:write` ∩ `insurance-claims`; enable when status is draft/returned; Opens mutation dialog with optimistic version.
     - **Submit:** gate `billing:write` ∩ `insurance-claims`; enable when validation passes; Moves record to approval/review queue.
     - **Approve / reject:** gate `billing:write` ∩ `financial:approve` ∩ `insurance-claims`; enable when pending approval and maker-checker satisfied; Records decision and reason.
     - **Post / process:** gate `billing:write` ∩ `insurance-claims`; enable when approved and period/workflow open; Runs atomic mutation and refreshes linked modules.
     - **Reverse / void:** gate `billing:write` ∩ `financial:approve` ∩ `insurance-claims`; enable when posted/processed and policy allows; Reason required; creates linked reversal, never deletes history.
     - **Print:** gate `claims:read` ∩ `evidence:export` ∩ `insurance-claims`; enable when formal document available; Opens document-template preview.
   - Bulk buttons:
     - **Submit selected:** gate `billing:write` ∩ `insurance-claims`; Only valid draft rows are submitted.
     - **Approve selected:** gate `billing:write` ∩ `financial:approve` ∩ `insurance-claims`; Maker-checker and homogeneous status required.
     - **Post/process selected:** gate `billing:write` ∩ `insurance-claims`; Atomic per record; failures do not hide successful rows.
     - **Export selected:** gate `claims:read` ∩ `evidence:export` ∩ `insurance-claims`; Audit event records filters and row count.
   - Hide actions that fail entitlement, permission, ABAC, status, period, or source-state checks.
   - Never hard-delete posted/finalized financial records; use archive, cancel, reversal, void, credit/debit note, refund, or audited reopening as defined by the tab specification.

6. **Implement forms, detail dialogs, and nested tables.**
   - Create/edit fields: `Batch Date`, `Payer`, `Plan/Contract`, `Facility`, `Currency`, `Service Period From`, `Service Period To`, `Submission Channel`, `Submission File`, `External Batch Reference`.
   - Detail sections: `Claim summary`, `Claim items`, `Validations & documents`, `Adjudication, denial & appeal`, `Submission & audit history`.
   - Use `showAppDialog` / `AppWorkspaceMutationDialog`, `AppWorkspaceDetailPanel`, shared form controls, responsive field rows, pinned footer actions, and the dialog/table selection conventions.
   - Keep forms in the current workspace. Cross-module handoffs may open only the authoritative owning module.

7. **Implement workflow, validation, permissions, and audit.**
   - Statuses represented by this tab: `Draft`, `Validated`, `Submitted`, `In review`, `Approved / Partially approved`, `Denied`, `Paid / Closed`.
   - Read gate: `claims:read` ∩ `insurance-claims`; mutate gate: `billing:write` ∩ `insurance-claims`; approval gate: `billing:write` ∩ `financial:approve` ∩ `insurance-claims`; export/print gate: `claims:read` ∩ `evidence:export` ∩ `insurance-claims`.
   - Apply these tab-specific validation requirements:
     - Client and server validate required values, lengths, formats, date ordering, and optimistic record version.
     - Backend revalidates tenant, facility, department, ownership, entitlement, permission, and current workflow state.
     - Public requests and responses use human-friendly identifiers; raw database IDs never appear.
     - Duplicate submission is prevented with an idempotency key for financial mutations.
     - Eligibility, coverage, authorization, required documents, deadlines, and payer rules are rechecked server-side.
   - Keep backend authorization authoritative and log all applicable create, update, submit, approve/reject, post/process, allocate, reconcile, reverse/void, archive/restore, export, and print events.

8. **Implement state synchronization and feedback.**
   - Extend the existing Riverpod workspace controller, entities, DTOs, and repository.
   - After mutations, refresh the affected row, open detail, active filtered count, affected sibling counts, and shell badge without reloading unrelated tabs.
   - Treat realtime events as reconciliation hints and defer conflicting refresh while saving.
   - Show observable loading, empty, partial, error, conflict, forbidden, validation, retry, and success states.

9. **Apply shared UI contracts.**
   - Follow `prompts/.cursor/screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, `localization.mdc`, `theming.mdc`, and `responsiveness.mdc`.
   - Reuse Pharmacy's route → query → `AppTabStrip` → `AppListTable` → detail dialog → mutation dialog → targeted refresh pattern.
   - Add all user-facing copy and accessibility text to English localization; do not hard-code UI strings.
   - Verify mobile, tablet, and desktop layouts in light and dark themes.

10. **Add and run verification.**
    - Add focused widget/controller tests for route restoration, columns, filters, counts, buttons, CRUD/workflow states, dialogs, authorization omission, export/print, and targeted refresh.
    - Add backend route/service tests for validation, pagination, ABAC scope, permission denial, status transitions, idempotency, concurrency, rollback, and audit.
    - Run `flutter analyze`, the focused Flutter tests, relevant backend tests, and any generator/contract checks affected by the change.
    - Do not proceed to Prompt 085 until all acceptance criteria below pass.

## Constraints

- Implement only this tab and directly required shared support; exclude unrelated refactoring.
- Do not change the tab label, menu ownership, column inventory, button intent, or module boundary without first updating `.cursor/billing-accounts-finance.md` and regenerating `.cursor/finance`.
- Reuse existing routes, controllers, repositories, validation, permissions, design-system components, dialogs, print paths, and localization patterns.
- Do not expose raw database IDs, raw enums, secrets, unnecessary PHI, or unauthorized rows/actions.
- Do not duplicate source records across Billing, Accounts & Finance, and Insurance & Claims.
- Preserve existing compatible behavior and migration paths while replacing incomplete tab implementations incrementally.

## Acceptance Criteria

- **AC1 (R1):** `/claims?section=claim-batches` opens the correct authorized tab, restores state, and omits it when access is denied.
- **AC2 (R2):** All API operations in `.cursor/finance/insurance-and-claims/claim-batches.md` use validated, scoped, versioned contracts and pass success, denial, conflict, rollback, and audit tests.
- **AC3 (R3):** The table exposes every specified column with correct default/optional visibility, formatting, sorting, filtering, totals, responsive behavior, and Settings/export availability.
- **AC4 (R4):** Filters, counts, rows, URL state, export, print, and saved views share one committed query and remain synchronized.
- **AC5 (R5):** Every specified toolbar, row, and bulk button appears only in valid authorized states and performs the documented result.
- **AC6 (R6):** Forms and detail dialogs use shared responsive components, contain the specified fields/sections/nested tables, and refresh in place after success.
- **AC7 (R7):** Status transitions, validation, maker-checker, period locks, immutability, permissions, ABAC, and audit are enforced by the backend and reflected by the UI.
- **AC8 (R8):** Loading, empty, partial, error, conflict, forbidden, retry, and success states are visible and stale data/counts do not remain after changes.
- **AC9 (R9):** The tab follows shared screen/tab/table/dialog/form/print/localization/theme/responsiveness rules at representative viewports and both themes.
- **AC10 (R10):** Static analysis, focused frontend tests, focused backend tests, and affected contract checks pass with no unrelated regressions.

## Relevant Files

- `.cursor/finance/insurance-and-claims/claim-batches.md`
- `.cursor/billing-accounts-finance.md`
- `.cursor/finance/_shared/workspace-pattern.md`
- `.cursor/finance/_shared/table-contract.md`
- `.cursor/finance/_shared/crud-and-dialog-contract.md`
- `.cursor/finance/_shared/permissions-and-entitlements.md`
- `.cursor/finance/_shared/api-state-and-audit-contract.md`
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/widgets/claim_batches_tab.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
- `backend/src/modules/claims-workspace/routes/claims-workspace.routes.js`
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_scope_navigation.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/localization.mdc`
- `prompts/.cursor/theming.mdc`
- `prompts/.cursor/responsiveness.mdc`
