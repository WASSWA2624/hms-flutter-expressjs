# Settings workspace UI inventory

## Context

Produce a complete, per-section inventory of the Settings page (`SettingsPage` at `/settings`). The goal is an exhaustive, readable catalog of every visible and reachable UI atom on that screen—not a redesign and not a new inventory folder under `screens/`.

**Settings accordion sections (tabs via `?tab=`):** `preferences`, `accessibility`, `account`, `leaves`, `rosters`, `administration`, `configuration`, `workspace` (visibility is permission-gated; default tab is `preferences`). Account may also use `?panel=` for nested account panels.

**Inventory** means listing what exists in presentation code, routes, access gates, and tests: strip chrome, toolbar actions, table surfaces (when present), columns, filters, dialogs (including nested / follow-on dialogs), forms inside those dialogs, Print / Export / Labels entry points, and permission-gated omissions.

Follow shared conventions in `prompts/.cursor/tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc` when naming surfaces and judging whether an atom is in or out of convention. Do not restate those rules; reference them when a finding depends on them. Settings may be accordion-led rather than `AppTabStrip`-led—still inventory each section as a tab-equivalent surface.

## Requirements

1. Inventory **every** Settings accordion section the page can show, including sections omitted for unauthorized users (note the permission that hides them).
2. For **each** section, list in this order:
   1. Section chrome: label, deep-link / `tab` (and `panel` when used) query value, expand/collapse behavior.
   2. Search / Filters / Settings / Export / Print and any context actions—exact labels as shown (or l10n keys when labels are localized).
   3. Inner surfaces: forms, lists/tables, toggles, or nested panels; for tables, default columns, all column choices, row-select behavior.
   4. Advanced filters (fields) and date/search field options when present; call out sections that intentionally omit Filters or date filter.
   5. Primary and secondary buttons / row actions reachable from that section.
   6. Dialogs opened from that section (detail, actions, pickers, mutation dialogs).
   7. Nested or follow-on dialogs/forms opened from those dialogs (one level of nesting at a time, chained until no further dialog opens).
   8. Forms hosted in those dialogs or inline: field groups at a summary level (not every validator).
   9. Print / label / document preview entry points tied to that section or its dialogs, including preview template names when identifiable.
3. Include shared HR / profile / access-admin / tenant surfaces reused by Settings whenever Settings opens them; mark them as **reused** vs Settings-owned widgets.
4. Record loading, empty, error, and success feedback surfaces that belong to each section or its dialogs.
5. Record RBAC/ABAC gates: which atoms render only when a named permission / `AccessRequirement` allows them; unauthorized atoms must be listed as **omitted when unauthorized**, not as disabled placeholders.
6. Deliver the inventory in the response (structured markdown). Do **not** write a new markdown inventory under a restored `screens/` folder.
7. Base the inventory on feature presentation code, routes, access maps, and existing tests—not on guesswork or a visual walkthrough alone.

## Constraints

- Do not implement UI changes, refactors, or convention fixes in this pass unless a finding is only a one-line label clarification required to name an atom accurately.
- Do not invent sections, dialogs, or print paths that are not reachable from Settings presentation code.
- Prefer extending/reusing existing shared components; the inventory must not recommend forking tab, table, dialog, form, or print chrome.
- Keep the catalog scannable: short bullets, one atom per line where practical; no prose essays per section.

## Acceptance Criteria

- [ ] Every Settings accordion section appears as its own section with the ordered checklist from Requirement 2.
- [ ] Every toolbar / section action is named (Filters, Settings, Export, Print when present, plus context actions).
- [ ] Every dialog and nested/follow-on dialog reachable from each section is named, with owner (Settings vs reused shared/HR/profile/access-admin).
- [ ] Forms inside those dialogs (or inline) are summarized; Print/label/preview entry points are listed or explicitly marked absent for that section.
- [ ] Permission-gated omissions are called out with the controlling access requirement or atom permission.
- [ ] Loading / empty / error / success feedback for section data and major dialogs is noted.
- [ ] No new files are created under a `screens/` inventory path.
- [ ] Findings that conflict with `tabs.mdc` / `tables.mdc` / `dialogs.mdc` / `forms.mdc` / `printing.mdc` are flagged as convention gaps (optional enhancement list, separate from the inventory).

## Verification

- Trace call sites from `settings_page.dart` and Settings widgets under `frontend/lib/features/settings/presentation/`.
- Cross-check section and action gates in `settings_access.dart` and related tests under `frontend/test/features/settings/`.
- Confirm deep-link `tab` / `panel` values via `SettingsPageQuery`.
- Spot-check section widgets: preferences, accessibility, account, leaves, rosters, administration, configuration, workspace.
- Manual check (optional): open Settings with a fully privileged user and an under-privileged user; confirm listed omissions match the UI.

## Relevant Files

- `frontend/lib/features/settings/presentation/pages/settings_page.dart`
- `frontend/lib/features/settings/presentation/settings_access.dart`
- `frontend/lib/features/settings/presentation/controllers/settings_workspace_controller.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_preferences_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_accessibility_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_account_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_leaves_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_rosters_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_administration_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_configuration_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_workspace_section.dart`
- `frontend/test/features/settings/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/prompt.mdc`
