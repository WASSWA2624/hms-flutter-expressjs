# OPD shared chrome — rule compliance

## Context

Remediate cross-tab OPD chrome so it fully complies with `screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc`. Inventory baseline: `tabs/03-opd/00-shared-chrome.md`. Gaps detail: `tabs/03-opd/99-convention-gaps.md`.

**Shared chrome** means: shell entry, workspace scaffold, `AppTabStrip`, shared `AppListTable` / `AppSearchBar` toolbar wiring, strip primary/secondary actions, and shared dialog hubs opened from multiple tabs.

## Requirements

1. Keep the desk on `AppTabStrip` + `AppTabItem` with unauthorized sections **omitted** — never disabled placeholders (`tabs.mdc`, `prompt.mdc`). Use `AppTabStripVariant.nested` only for subordinate category tabs already modeled by the feature.
2. Implement **authoritative tab counts** for every countable visible tab per `tabs.mdc`: prefer server / workspace summary totals; do not badge from painted page length alone. When Advanced filters or search narrow the active tab, the active badge must show the filtered total for that query; sibling badges must follow one consistent workspace model (shared filter context **or** dedicated scope totals — pick one model and apply it uniformly).
3. Assign `AppTabCountTone` per urgency: use `warning` / `danger` only for queues that need attention; use `info` for non-urgent scopes unless a test-documented product exception justifies otherwise (`tabs.mdc`).
4. Keep table trailing action order exactly: **Filters → Settings → Export → Start OPD** (normalize to Filters → Settings → Export → Print → context when Print applies). Use shared labels that resolve to `Filters`, `Settings`, `Export`, and `Print` (`tables.mdc`, `printing.mdc`). Prefer `commonFiltersActionLabel` / `commonPrintActionLabel` (or equivalent keys that resolve to those strings).
5. Where the inventory currently omits table Print, **add** preview-first Print after Export on every printable list table unless a numbered product exception is recorded in tests (`tables.mdc`, `printing.mdc`). Omit Print when unauthorized.
6. Gate Export with an explicit desk permission check via `canExport` (prefer ∩ `evidence:export` or the feature’s documented export atom); omit Export when unauthorized (`tables.mdc`).
7. Keep strip / context actions after Print (or after Export when Print is omitted by justified exception); omit when unauthorized. Preserve in-desk create/edit/detail flows; reuse shared fields/forms (`forms.mdc`); hide tenant/facility/session context fields the operator already knows.
8. Ensure dialogs opened from shared chrome use **generic titles**, flat bodies, pinned footers, and maximized defaults per `dialogs.mdc`. Identity stays in the body. Do not nest `AppCollapsibleSection` inside another.
9. Any Print trigger reachable from this desk (table toolbar or nested hubs) must use trigger label exactly `Print` and shared preview-first flow (`printing.mdc`).
10. Cover loading, empty, error, success, and retry for workspace load, tab switch, filter apply, export, and print. Synchronize table + all affected tab counts after mutations (`tabs.mdc`, `prompt.mdc`).
11. Preserve deep-link `section` / search / id / action behavior and `syncWorkspaceLocation` in-desk URL sync (`screens.mdc`).

## Constraints

- Prefer extending `AppListTable` / `AppSearchBar` / shared printing once; do not invent a feature-only Print button row.
- Do not add nested feature routes for multi-step desk work.
- Do not restate rule text in code comments; reference the rule file name when a justified exception is unavoidable.
- Do not fork parallel tab, table, dialog, form, or print chrome when a shared path exists or can be extended.

## Acceptance Criteria

- [ ] Every visible countable tab shows a count badge sourced per Requirements 2–3; tones match the urgency policy.
- [ ] Toolbar order on every printable table tab matches Requirement 4 (with unauthorized controls omitted).
- [ ] Print always opens shared preview before device print when present; trigger label is `Print`.
- [ ] Export is omitted when the export gate denies; present when allowed.
- [ ] Unauthorized tabs and strip actions are absent (not disabled).
- [ ] Dialogs opened from shared chrome keep generic titles and reuse shared form/dialog primitives.
- [ ] Mutations refresh table rows and all visible tab counts that can change.
- [ ] `tabs/03-opd/00-shared-chrome.md` updated to match.

## Verification

- Widget / golden or integration tests for toolbar order and omit-when-unauthorized Export / Print / context actions.
- Unit or controller tests for authoritative counts and filtered active-tab badge.
- Manual: light/dark + narrow viewport strip overflow; print preview section/column toggles update live preview when Print applies.
- Regression: deep links for `section=` / search / action still open the correct in-desk surfaces.

## Relevant Files

- `tabs/03-opd/00-shared-chrome.md`
- `tabs/03-opd/99-convention-gaps.md`
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/features/opd/presentation/opd_access.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/components/app_tab_strip.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/opd/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/screens.mdc`
