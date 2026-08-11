# Accounts workspace UI inventory

## Context

Produce a complete, per-tab inventory of the Accounts workspace (`AccountsWorkspacePage` at `/accounts`, including GL sub-workspace when embedded). The goal is an exhaustive, readable catalog of every visible and reachable UI atom on that screen—not a redesign and not a new inventory folder under `screens/`.

**Accounts desk sections (tabs):** `work`, `journals`, `approvals`, `gl`, `ledgers`, `chart`, `books` (`AccountsDeskSection`).

**Inventory** means listing what exists in presentation code, routes, access gates, and tests: strip chrome, toolbar actions, table surfaces, columns, filters, dialogs (including nested / follow-on dialogs), forms inside those dialogs, Print / Export / Labels entry points, and permission-gated omissions.

Follow shared conventions in `prompts/.cursor/tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc` when naming surfaces and judging whether an atom is in or out of convention. Do not restate those rules; reference them when a finding depends on them.

## Requirements

1. Inventory **every** `AccountsDeskSection` tab the workspace can show, including tabs omitted for unauthorized users (note the permission that hides them).
2. For **each** tab, list in this order:
   1. Tab strip: label, count source, count tone, deep-link / `section` query value.
   2. Search / Filters / Settings / Export / Print and any context actions (e.g. Post journal, Approve)—exact labels as shown (or l10n keys when labels are localized).
   3. Table: row model, default columns, all column choices, row-select behavior.
   4. Advanced filters (fields) and date/search field options when present; call out tabs that intentionally omit Filters or date filter.
   5. Primary and secondary buttons / row actions reachable from that tab.
   6. Dialogs opened from that tab (detail, actions, pickers, mutation dialogs).
   7. Nested or follow-on dialogs/forms opened from those dialogs (one level of nesting at a time, chained until no further dialog opens).
   8. Forms hosted in those dialogs: field groups at a summary level (not every validator).
   9. Print / label / document preview entry points tied to that tab or its dialogs, including preview template names when identifiable (journal, chart, GL, books, approval, patient ledger).
3. Include shared billing / patient ledger surfaces reused by Accounts whenever Accounts opens them; mark them as **reused** vs Accounts-owned widgets. Note `AccountsGlWorkspacePage` if it is opened as a nested/route surface from the `gl` tab.
4. Record loading, empty, error, and success feedback surfaces that belong to each tab or its dialogs.
5. Record RBAC/ABAC gates: which atoms render only when a named permission / `AccessRequirement` allows them; unauthorized atoms must be listed as **omitted when unauthorized**, not as disabled placeholders.
6. Deliver the inventory in the response (structured markdown). Do **not** write a new markdown inventory under a restored `screens/` folder.
7. Base the inventory on feature presentation code, routes, access maps, and existing tests—not on guesswork or a visual walkthrough alone.

## Constraints

- Do not implement UI changes, refactors, or convention fixes in this pass unless a finding is only a one-line label clarification required to name an atom accurately.
- Do not invent tabs, dialogs, or print paths that are not reachable from Accounts presentation code.
- Prefer extending/reusing existing shared components; the inventory must not recommend forking tab, table, dialog, form, or print chrome.
- Keep the catalog scannable: short bullets, one atom per line where practical; no prose essays per tab.

## Acceptance Criteria

- [ ] Every `AccountsDeskSection` appears as its own section with the ordered checklist from Requirement 2.
- [ ] Every list-table toolbar action on each tab is named (Filters, Settings, Export, Print when present, plus context actions).
- [ ] Every dialog and nested/follow-on dialog reachable from each tab is named, with owner (Accounts vs reused shared/billing/patient).
- [ ] Forms inside those dialogs are summarized; Print/label/preview entry points are listed or explicitly marked absent for that tab.
- [ ] Permission-gated omissions are called out with the controlling access requirement or atom permission.
- [ ] Loading / empty / error / success feedback for tab data and major dialogs is noted.
- [ ] No new files are created under a `screens/` inventory path.
- [ ] Findings that conflict with `tabs.mdc` / `tables.mdc` / `dialogs.mdc` / `forms.mdc` / `printing.mdc` are flagged as convention gaps (optional enhancement list, separate from the inventory).

## Verification

- Trace call sites from `accounts_workspace_page.dart` / `accounts_gl_workspace_page.dart` and Accounts widgets under `frontend/lib/features/accounts/presentation/`.
- Cross-check tab and action gates in `accounts_access.dart` and related tests under `frontend/test/features/accounts/`.
- Confirm deep-link section values via `AccountsDeskSection.sectionQueryValue`.
- Spot-check journal/chart/GL/ledger/period dialogs and print option helpers.
- Manual check (optional): open Accounts with a fully privileged user and an under-privileged user; confirm listed omissions match the UI.

## Relevant Files

- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/pages/accounts_gl_workspace_page.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/lib/features/accounts/domain/entities/accounts_entities.dart`
- `frontend/lib/features/accounts/presentation/controllers/accounts_workspace_controller.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_form_dialogs.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_journal_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_gl_dialog.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_chart_dialogs.dart`
- `frontend/lib/features/accounts/presentation/widgets/accounts_patient_ledger_dialog.dart`
- `frontend/test/features/accounts/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/prompt.mdc`
