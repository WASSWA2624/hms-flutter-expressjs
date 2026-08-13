# Prompt 058 — Implement Write-offs

## Context

- **Sequence:** 058 of 159
- **Phase:** Billing collections and receivables
- **Prerequisite:** Prompt 057 — Refunds (`prompts/01-finance-tabs/02-billing/057-refunds.md`).
- **Menu path:** `Billing → Write-offs`
- **Canonical route:** `/billing?section=write-offs`
- **Tab profile:** `transaction` table/worklist
- **Authoritative tab specification:** `.cursor/finance/billing/write-offs.md`
- **Finance source of truth:** `.cursor/billing-accounts-finance.md`

Implement this prompt only after the prerequisite prompt passes its acceptance criteria. Treat the tab specification as authoritative for domain behavior, columns, API operations, statuses, permissions, buttons, forms, nested detail tables, and acceptance criteria.

## Requirements

1. **Register and scope the tab.**
   - Implement the `Write-offs` tab at `Billing → Write-offs` with canonical section slug `write-offs`.
   - Preserve compatible existing deep-link aliases, but generate new links only with the canonical slug.
   - Reopening the route must focus the existing tab and restore committed search, filters, sorting, pagination, and column settings.
   - Keep the Billing menu as one flat workspace whose permanent tabs share the same route.

2. **Implement the backend and data contract.**
   - Implement every list, detail, CRUD, workflow, report, or reconciliation operation defined under **Target API contract** in `.cursor/finance/billing/write-offs.md`.
   - Extend the existing workspace route/service/repository rather than creating a parallel API.
   - Use Zod validation, `snake_case` JSON, public `human_friendly_id`, paginated `data` plus `meta`, optimistic versions, idempotency for financial mutations, and database transactions.
   - Enforce status transitions, period locks, source-document integrity, and audit logging server-side.

3. **Build the primary table with the exact source columns.**
   - Use `AppListTable`; do not create custom table chrome.
   - Preserve this source order in Settings/export while applying the default/optional visibility defined in `.cursor/finance/billing/write-offs.md`:
     `Write-off No.`, `Request Date`, `Invoice No.`, `Patient/Customer`, `Payer`, `Invoice Balance`, `Requested Amount`, `Approved Amount`, `Currency`, `Write-off Category`, `Reason`, `Approval Status`, `Approved By`, `Journal Entry No.`, `Posted Date`.
   - Implement server sort keys, atomic cells, localized formatting, status badges, monetary alignment/precision, server-filtered totals, a mobile item builder, horizontal overflow, pinned footer, and empty-row padding.

4. **Implement filters and table controls.**
   - Implement these domain filters in addition to comprehensive field filters from the specification: `Search`, `Status`, `Date/period`, `Party`, `Currency`, `Amount range`.
   - Follow `prompts/.cursor/tables.mdc` for Search and the standard Filters → Settings → Export → Print toolbar sequence.
   - Use one committed query model for tab count, table rows, Advanced filters, export, print, URL restoration, and saved views.
   - Implement these context-specific toolbar buttons:
     - **Request write-off:** gate `billing:write` ∩ `billing-payments`; enable when open eligible balance; Creates an approval request.

5. **Implement row actions, bulk actions, and CRUD.**
   - Row buttons:
     - **View:** gate `billing:read` ∩ `billing-payments`; enable when always; Opens a detail `AppDialog` using the human-friendly reference.
     - **Edit draft:** gate `billing:write` ∩ `billing-payments`; enable when status is draft/returned; Opens mutation dialog with optimistic version.
     - **Submit:** gate `billing:write` ∩ `billing-payments`; enable when validation passes; Moves record to approval/review queue.
     - **Approve / reject:** gate `billing:write` ∩ `financial:approve` ∩ `billing-payments`; enable when pending approval and maker-checker satisfied; Records decision and reason.
     - **Post / process:** gate `billing:write` ∩ `billing-payments`; enable when approved and period/workflow open; Runs atomic mutation and refreshes linked modules.
     - **Reverse / void:** gate `billing:write` ∩ `financial:approve` ∩ `billing-payments`; enable when posted/processed and policy allows; Reason required; creates linked reversal, never deletes history.
     - **Print:** gate `billing:read` ∩ `evidence:export` ∩ `billing-payments`; enable when formal document available; Opens document-template preview.
   - Bulk buttons:
     - **Submit selected:** gate `billing:write` ∩ `billing-payments`; Only valid draft rows are submitted.
     - **Approve selected:** gate `billing:write` ∩ `financial:approve` ∩ `billing-payments`; Maker-checker and homogeneous status required.
     - **Post/process selected:** gate `billing:write` ∩ `billing-payments`; Atomic per record; failures do not hide successful rows.
     - **Export selected:** gate `billing:read` ∩ `evidence:export` ∩ `billing-payments`; Audit event records filters and row count.
   - Hide actions that fail entitlement, permission, ABAC, status, period, or source-state checks.
   - Never hard-delete posted/finalized financial records; use archive, cancel, reversal, void, credit/debit note, refund, or audited reopening as defined by the tab specification.

6. **Implement forms, detail dialogs, and nested tables.**
   - Create/edit fields: `Request Date`, `Invoice No.`, `Patient/Customer`, `Payer`, `Requested Amount`, `Approved Amount`, `Currency`, `Write-off Category`, `Reason`, `Posted Date`.
   - Detail sections: `Summary`, `Related records`, `Attachments`, `Activity & audit`.
   - Use `showAppDialog` / `AppWorkspaceMutationDialog`, `AppWorkspaceDetailPanel`, shared form controls, responsive field rows, pinned footer actions, and the dialog/table selection conventions.
   - Keep forms in the current workspace. Cross-module handoffs may open only the authoritative owning module.

7. **Implement workflow, validation, permissions, and audit.**
   - Statuses represented by this tab: `Draft`, `Submitted`, `Approved`, `Posted / Processed`, `Reversed / Voided`.
   - Read gate: `billing:read` ∩ `billing-payments`; mutate gate: `billing:write` ∩ `billing-payments`; approval gate: `billing:write` ∩ `financial:approve` ∩ `billing-payments`; export/print gate: `billing:read` ∩ `evidence:export` ∩ `billing-payments`.
   - Apply these tab-specific validation requirements:
     - Client and server validate required values, lengths, formats, date ordering, and optimistic record version.
     - Backend revalidates tenant, facility, department, ownership, entitlement, permission, and current workflow state.
     - Public requests and responses use human-friendly identifiers; raw database IDs never appear.
     - Duplicate submission is prevented with an idempotency key for financial mutations.
     - Amounts must be positive and cannot exceed the eligible, unallocated, refundable, or open balance.
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
    - Do not proceed to Prompt 059 until all acceptance criteria below pass.

## Constraints

- Implement only this tab and directly required shared support; exclude unrelated refactoring.
- Do not change the tab label, menu ownership, column inventory, button intent, or module boundary without first updating `.cursor/billing-accounts-finance.md` and regenerating `.cursor/finance`.
- Reuse existing routes, controllers, repositories, validation, permissions, design-system components, dialogs, print paths, and localization patterns.
- Do not expose raw database IDs, raw enums, secrets, unnecessary PHI, or unauthorized rows/actions.
- Do not duplicate source records across Billing, Accounts & Finance, and Insurance & Claims.
- Preserve existing compatible behavior and migration paths while replacing incomplete tab implementations incrementally.

## Acceptance Criteria

- **AC1 (R1):** `/billing?section=write-offs` opens the correct authorized tab, restores state, and omits it when access is denied.
- **AC2 (R2):** All API operations in `.cursor/finance/billing/write-offs.md` use validated, scoped, versioned contracts and pass success, denial, conflict, rollback, and audit tests.
- **AC3 (R3):** The table exposes every specified column with correct default/optional visibility, formatting, sorting, filtering, totals, responsive behavior, and Settings/export availability.
- **AC4 (R4):** Filters, counts, rows, URL state, export, print, and saved views share one committed query and remain synchronized.
- **AC5 (R5):** Every specified toolbar, row, and bulk button appears only in valid authorized states and performs the documented result.
- **AC6 (R6):** Forms and detail dialogs use shared responsive components, contain the specified fields/sections/nested tables, and refresh in place after success.
- **AC7 (R7):** Status transitions, validation, maker-checker, period locks, immutability, permissions, ABAC, and audit are enforced by the backend and reflected by the UI.
- **AC8 (R8):** Loading, empty, partial, error, conflict, forbidden, retry, and success states are visible and stale data/counts do not remain after changes.
- **AC9 (R9):** The tab follows shared screen/tab/table/dialog/form/print/localization/theme/responsiveness rules at representative viewports and both themes.
- **AC10 (R10):** Static analysis, focused frontend tests, focused backend tests, and affected contract checks pass with no unrelated regressions.

## Relevant Files

- `.cursor/finance/billing/write-offs.md`
- `.cursor/billing-accounts-finance.md`
- `.cursor/finance/_shared/workspace-pattern.md`
- `.cursor/finance/_shared/table-contract.md`
- `.cursor/finance/_shared/crud-and-dialog-contract.md`
- `.cursor/finance/_shared/permissions-and-entitlements.md`
- `.cursor/finance/_shared/api-state-and-audit-contract.md`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/widgets/write_offs_tab.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `backend/src/modules/billing/routes/billing.routes.js`
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
