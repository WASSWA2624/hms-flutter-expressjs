# Prompt 001 — Implement Suppliers

## Context

- **Sequence:** 001 of 011 in `prompts/01-accounts-and-finance/05-purchases-and-payables/`
- **Overall step:** 040 of 158
- **Phase:** Accounts operations — purchases and payables
- **Prerequisite:** `Accounts & Finance → Bank Management → Bank Reconciliations` (`prompts/01-accounts-and-finance/04-bank-management/008-bank-reconciliations.md`).
- **Menu path:** `Accounts & Finance → Purchases & Payables → Suppliers`
- **Canonical route:** `/accounts?section=suppliers`
- **Surface profile:** `master` table/worklist tab
- **Navigation model:** `Accounts & Finance → Purchases & Payables` are the two sidebar menu levels; this surface is a tab in that menu item's flat tab strip
- **Authoritative tab specification:** `.cursor/finance/accounts-and-finance/purchases-and-payables/suppliers.md`
- **Finance source of truth:** `.cursor/billing-accounts-finance.md`

Implement this prompt only after the prerequisite prompt passes its acceptance criteria. Treat the tab specification as authoritative for domain behavior, columns, API operations, statuses, permissions, buttons, forms, nested detail tables, and acceptance criteria.

## Requirements

1. **Audit the existing implementation before writing code.**
   - Run the five-step reuse audit in `.cursor/finance/_shared/existing-implementation.md`: backend module/model/service/route, frontend panel/table/dialog/DTO/entity/repository/controller, permission key/entitlement/ABAC scope/access atom, localized string/formatter/print helper/export mapping, then the residual gap list.
   - Extend the module that already owns each record. Do not add a parallel model, route family, controller, panel, permission key, or formatter for something another module owns.
   - Reuse the existing currency stack (`frontend/lib/shared/components/app_currency.dart`, `frontend/lib/core/currency/`) for resolution, precision, rounding, conversion, and formatting. Never add a currency registry, rate table, or second conversion path.
   - Reuse the existing Accounts & Finance workspace, controller, entities, DTOs, and repositories in `frontend/lib/features/accounts/` and `backend/src/modules/accounts-workspace/`.
   - State the audit outcome in the change description: what already existed, what is extended, and what genuinely did not exist.

2. **Register and scope the tab.**
   - Implement the `Suppliers` tab at `Accounts & Finance → Purchases & Payables → Suppliers` with canonical section slug `suppliers`.
   - Preserve compatible existing deep-link aliases, but generate new links only with the canonical slug.
   - Reopening the route must focus the existing tab and restore committed search, filters, sorting, pagination, and column settings.
   - Add this tab to the flat `AppTabStrip` of the `Purchases & Payables` sidebar menu item. The menu nests exactly one level: never add a second sidebar level, a category `AppTabStrip` above the section strip, or an `AppTabStripVariant.nested` layer. See `.cursor/finance/_shared/navigation-model.md`.

3. **Implement the backend and data contract.**
   - Implement every list, detail, CRUD, workflow, report, or reconciliation operation defined under **Target API contract** in `.cursor/finance/accounts-and-finance/purchases-and-payables/suppliers.md`.
   - Extend the existing workspace route/service/repository rather than creating a parallel API.
   - Use Zod validation, `snake_case` JSON, public `human_friendly_id`, paginated `data` plus `meta`, optimistic versions, idempotency for financial mutations, and database transactions.
   - Enforce status transitions, period locks, source-document integrity, and audit logging server-side.

4. **Build the primary table with the exact source columns.**
   - Use `AppListTable`; do not create custom table chrome.
   - Preserve this source order in Settings/export while applying the default/optional visibility defined in `.cursor/finance/accounts-and-finance/purchases-and-payables/suppliers.md`:
     `Supplier No.`, `Supplier Name`, `Supplier Type`, `Tax ID`, `Contact Person`, `Phone`, `Email`, `Address`, `Payment Terms`, `Default Currency`, `Credit Limit`, `Current AP Balance`, `Bank Account Summary`, `On Hold`, `Last Transaction Date`, `Supplier Status`.
   - Implement server sort keys, atomic cells, localized formatting, status badges, monetary alignment/precision, server-filtered totals, a mobile item builder, horizontal overflow, pinned footer, and empty-row padding.

5. **Implement filters and table controls.**
   - Implement these domain filters in addition to comprehensive field filters from the specification: `Search`, `Status`, `Date/period`, `Party`, `Currency`, `Amount range`.
   - Follow `prompts/.cursor/tables.mdc` for Search and the standard Filters → Settings → Export → Print toolbar sequence.
   - Use one committed query model for the tab count badge, table rows, Advanced filters, export, print, URL restoration, and saved views.
   - Implement these context-specific toolbar buttons:
     - **New record:** gate `accounts:write` ∩ `facility-accounts`; enable when write permitted; Opens the Suppliers create dialog.

6. **Implement row actions, bulk actions, and CRUD.**
   - Row buttons:
     - **View:** gate `accounts:read` ∩ `facility-accounts`; enable when always; Opens a detail `AppDialog` using the human-friendly reference.
     - **Edit:** gate `accounts:write` ∩ `facility-accounts`; enable when record active/draft and version current; Opens prefilled edit dialog.
     - **Clone:** gate `accounts:write` ∩ `facility-accounts`; enable when record clonable; Creates an unsaved copy with a new reference.
     - **Activate / deactivate:** gate `accounts:write` ∩ `facility-accounts`; enable when transition allowed; Requires confirmation and refreshes dependants.
     - **Archive / restore:** gate `accounts:write` ∩ `facility-accounts`; enable when not referenced by a blocking workflow; Soft archive only; never hard-delete referenced data.
   - Bulk buttons:
     - **Activate / deactivate selected:** gate `accounts:write` ∩ `facility-accounts`; Only compatible, unblocked records are changed.
     - **Archive selected:** gate `accounts:write` ∩ `facility-accounts`; Soft archive; partial failures return per-row reasons.
     - **Export selected:** gate `accounts:read` ∩ `evidence:export` ∩ `facility-accounts`; Exports selected rows in visible-column order.
   - Hide actions that fail entitlement, permission, ABAC, status, period, or source-state checks.
   - Never hard-delete posted/finalized financial records; use archive, cancel, reversal, void, credit/debit note, refund, or audited reopening as defined by the tab specification.

7. **Implement forms, detail dialogs, and nested tables.**
   - Create/edit fields: `Supplier No.`, `Supplier Name`, `Supplier Type`, `Tax ID`, `Contact Person`, `Phone`, `Email`, `Address`, `Payment Terms`, `Default Currency`.
   - Detail sections: `Summary`, `Items`, `Document chain`, `Approvals & audit`.
   - Use `showAppDialog` / `AppWorkspaceMutationDialog`, `AppWorkspaceDetailPanel`, shared form controls, responsive field rows, pinned footer actions, and the dialog/table selection conventions.
   - Keep forms in the current workspace. Cross-module handoffs may open only the authoritative owning module.

8. **Implement workflow, validation, permissions, and audit.**
   - Statuses represented by this tab: `Draft`, `Active`, `Inactive`, `Archived`.
   - Read gate: `accounts:read` ∩ `facility-accounts`; mutate gate: `accounts:write` ∩ `facility-accounts`; approval gate: `accounts:write` ∩ `financial:approve` ∩ `facility-accounts`; export/print gate: `accounts:read` ∩ `evidence:export` ∩ `facility-accounts`.
   - Apply these tab-specific validation requirements:
     - Client and server validate required values, lengths, formats, date ordering, and optimistic record version.
     - Backend revalidates tenant, facility, department, ownership, entitlement, permission, and current workflow state.
     - Public requests and responses use human-friendly identifiers; raw database IDs never appear.
     - Duplicate submission is prevented with an idempotency key for financial mutations.
     - Posting, close, reversal, and adjustment actions are blocked when the fiscal period is locked.
   - Keep backend authorization authoritative and log all applicable create, update, submit, approve/reject, post/process, allocate, reconcile, reverse/void, archive/restore, export, and print events.

9. **Implement state synchronization and feedback.**
   - Extend the existing Riverpod workspace controller, entities, DTOs, and repository.
   - After mutations, refresh the affected row, open detail, active filtered count, affected sibling counts, and shell badge without reloading unrelated tabs.
   - Treat realtime events as reconciliation hints and defer conflicting refresh while saving.
   - Show observable loading, empty, partial, error, conflict, forbidden, validation, retry, and success states.

10. **Apply shared UI contracts.**
    - Follow `prompts/.cursor/screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, `localization.mdc`, `theming.mdc`, and `responsiveness.mdc`.
    - Reuse Pharmacy's route → query → flat `AppTabStrip` → `AppListTable` → detail dialog → mutation dialog → targeted refresh pattern.
    - Add all user-facing copy and accessibility text to English localization; do not hard-code UI strings.
    - Verify mobile, tablet, and desktop layouts in light and dark themes.

11. **Add and run verification.**
    - Add focused widget/controller tests for route restoration, columns, filters, counts, buttons, CRUD/workflow states, dialogs, authorization omission, export/print, and targeted refresh.
    - Add backend route/service tests for validation, pagination, ABAC scope, permission denial, status transitions, idempotency, concurrency, rollback, and audit.
    - Run `flutter analyze`, the focused Flutter tests, relevant backend tests, and any generator/contract checks affected by the change.
    - Do not proceed to `Accounts & Finance → Purchases & Payables → Purchase Requisitions` (`prompts/01-accounts-and-finance/05-purchases-and-payables/002-purchase-requisitions.md`) until all acceptance criteria below pass.

## Constraints

- Implement only this tab and directly required shared support; exclude unrelated refactoring.
- Do not change the tab label, menu ownership, column inventory, button intent, or module boundary without first updating `.cursor/billing-accounts-finance.md` and regenerating `.cursor/finance`.
- Reuse existing routes, controllers, repositories, validation, permissions, design-system components, dialogs, print paths, and localization patterns.
- Do not expose raw database IDs, raw enums, secrets, unnecessary PHI, or unauthorized rows/actions.
- Do not duplicate source records across Billing, Accounts & Finance, and Insurance & Claims.
- Do not re-implement capabilities the codebase already provides. Extend the owning module instead, and never introduce a second source of truth for a record another module owns.
- Preserve existing compatible behavior and migration paths while replacing incomplete surface implementations incrementally.

## Acceptance Criteria

- **AC1 (R1):** The reuse audit is documented, and the change adds no parallel model, route, panel, permission key, or formatter for a capability another module already owns.
- **AC2 (R2):** `/accounts?section=suppliers` opens the correct authorized tab, restores state, and omits it when access is denied.
- **AC3 (R3):** All API operations in `.cursor/finance/accounts-and-finance/purchases-and-payables/suppliers.md` use validated, scoped, versioned contracts and pass success, denial, conflict, rollback, and audit tests.
- **AC4 (R4):** The table exposes every specified column with correct default/optional visibility, formatting, sorting, filtering, totals, responsive behavior, and Settings/export availability.
- **AC5 (R5):** Filters, counts, rows, URL state, export, print, and saved views share one committed query and remain synchronized.
- **AC6 (R6):** Every specified toolbar, row, and bulk button appears only in valid authorized states and performs the documented result.
- **AC7 (R7):** Forms and detail dialogs use shared responsive components, contain the specified fields/sections/nested tables, and refresh in place after success.
- **AC8 (R8):** Status transitions, validation, maker-checker, period locks, immutability, permissions, ABAC, and audit are enforced by the backend and reflected by the UI.
- **AC9 (R9):** Loading, empty, partial, error, conflict, forbidden, retry, and success states are visible and stale data/counts do not remain after changes.
- **AC10 (R10):** The surface follows shared screen/tab/table/dialog/form/print/localization/theme/responsiveness rules at representative viewports and both themes.
- **AC11 (R11):** Static analysis, focused frontend tests, focused backend tests, and affected contract checks pass with no unrelated regressions.

## Relevant Files

- `.cursor/finance/accounts-and-finance/purchases-and-payables/suppliers.md`
- `.cursor/billing-accounts-finance.md`
- `.cursor/finance/_shared/existing-implementation.md`
- `.cursor/finance/_shared/navigation-model.md`
- `.cursor/finance/_shared/workspace-pattern.md`
- `.cursor/finance/_shared/table-contract.md`
- `.cursor/finance/_shared/crud-and-dialog-contract.md`
- `.cursor/finance/_shared/permissions-and-entitlements.md`
- `.cursor/finance/_shared/api-state-and-audit-contract.md`
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_suppliers_panel.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `backend/src/modules/accounts-workspace/routes/accounts-workspace.routes.js`
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
