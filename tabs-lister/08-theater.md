# Theater workspace UI inventory

## Context

Produce a complete, per-tab inventory of the Theater workspace (`TheaterWorkspacePage` at `/theater`). The goal is an exhaustive, readable catalog of every visible and reachable UI atom on that screen—not a redesign and not a new inventory folder under `screens/`.

**Theater sections (tabs):** `scheduled`, `inTheater`, `recovery`, `all`, `followUps` (`TheaterSection`). Detail deep-link panels: `checklist`, `anesthesia`, `postop`, `resources` (`TheaterDetailPanel`).

**Inventory** means listing what exists in presentation code, routes, access gates, and tests: strip chrome, toolbar actions, table surfaces, columns, filters, dialogs (including nested / follow-on dialogs), forms inside those dialogs, Print / Export / Labels entry points, and permission-gated omissions.

Follow shared conventions in `prompts/.cursor/tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc` when naming surfaces and judging whether an atom is in or out of convention. Do not restate those rules; reference them when a finding depends on them.

## Requirements

1. Inventory **every** `TheaterSection` tab the workspace can show, including tabs omitted for unauthorized users (note the permission that hides them).
2. For **each** tab, list in this order:
   1. Tab strip: label, count source, count tone, deep-link / `section` query value.
   2. Search / Filters / Settings / Export / Print and any context actions—exact labels as shown (or l10n keys when labels are localized).
   3. Table: row model, default columns, all column choices, row-select behavior.
   4. Advanced filters (fields) and date/search field options when present; call out tabs that intentionally omit Filters or date filter.
   5. Primary and secondary buttons / row actions reachable from that tab.
   6. Dialogs opened from that tab (detail, actions, pickers, mutation dialogs), including panels opened via deep links.
   7. Nested or follow-on dialogs/forms opened from those dialogs (one level of nesting at a time, chained until no further dialog opens).
   8. Forms hosted in those dialogs: field groups at a summary level (not every validator).
   9. Print / label / document preview entry points tied to that tab or its dialogs, including preview template names when identifiable.
3. Include shared clinical / IPD / patient / billing surfaces reused by Theater whenever Theater opens them; mark them as **reused** vs Theater-owned widgets.
4. Record loading, empty, error, and success feedback surfaces that belong to each tab or its dialogs.
5. Record RBAC/ABAC gates: which atoms render only when a named permission / `AccessRequirement` allows them; unauthorized atoms must be listed as **omitted when unauthorized**, not as disabled placeholders.
6. Deliver the inventory in the response (structured markdown). Do **not** write a new markdown inventory under a restored `screens/` folder.
7. Base the inventory on feature presentation code, routes, access maps, and existing tests—not on guesswork or a visual walkthrough alone.

## Constraints

- Do not implement UI changes, refactors, or convention fixes in this pass unless a finding is only a one-line label clarification required to name an atom accurately.
- Do not invent tabs, dialogs, or print paths that are not reachable from Theater presentation code.
- Prefer extending/reusing existing shared components; the inventory must not recommend forking tab, table, dialog, form, or print chrome.
- Keep the catalog scannable: short bullets, one atom per line where practical; no prose essays per tab.

## Acceptance Criteria

- [ ] Every `TheaterSection` appears as its own section with the ordered checklist from Requirement 2.
- [ ] Every list-table toolbar action on each tab is named (Filters, Settings, Export, Print when present, plus context actions).
- [ ] Every dialog and nested/follow-on dialog reachable from each tab is named, with owner (Theater vs reused shared/clinical/IPD/patient).
- [ ] Forms inside those dialogs are summarized; Print/label/preview entry points are listed or explicitly marked absent for that tab.
- [ ] Permission-gated omissions are called out with the controlling access requirement or atom permission.
- [ ] Loading / empty / error / success feedback for tab data and major dialogs is noted.
- [ ] No new files are created under a `screens/` inventory path.
- [ ] Findings that conflict with `tabs.mdc` / `tables.mdc` / `dialogs.mdc` / `forms.mdc` / `printing.mdc` are flagged as convention gaps (optional enhancement list, separate from the inventory).

## Verification

- Trace call sites from `theater_workspace_page.dart` and Theater widgets under `frontend/lib/features/theater/presentation/`.
- Cross-check tab and action gates in `theater_access.dart` and related tests under `frontend/test/features/theater/`.
- Confirm deep-link section values via `TheaterSection.queryValue` / `TheaterSectionX.fromQuery`.
- Spot-check Theater detail panels and any reused clinical/patient dialogs.
- Manual check (optional): open Theater with a fully privileged user and an under-privileged user; confirm listed omissions match the UI.

## Relevant Files

- `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
- `frontend/lib/features/theater/presentation/theater_access.dart`
- `frontend/lib/features/theater/domain/entities/theater_entities.dart`
- `frontend/lib/features/theater/presentation/controllers/theater_workspace_controller.dart`
- `frontend/test/features/theater/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/prompt.mdc`
