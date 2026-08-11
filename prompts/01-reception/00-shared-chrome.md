# Reception shared chrome — rule compliance

## Context

Remediate cross-tab Reception chrome so it fully complies with `screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc`. Inventory baseline: `tabs/01-reception/00-shared-chrome.md`. Gaps detail: `tabs/01-reception/99-convention-gaps.md`.

**Shared chrome** means: shell entry, `AsyncStateScaffold`, `AppTabStrip`, shared `AppListTable` / `AppSearchBar` toolbar wiring, Schedule / Register entry points, and shared dialog hubs opened from multiple tabs.

## Requirements

1. Keep the desk on `AppTabStrip` + `AppTabItem` (standard variant) with unauthorized sections **omitted** (`receptionDeskSectionRequirement`) — never disabled placeholders (`tabs.mdc`, `prompt.mdc`).
2. Implement **authoritative tab counts** for every countable visible tab per `tabs.mdc`: prefer server / workspace summary totals; do not badge from painted page length alone. When Advanced filters or search narrow the active tab, the active badge must show the filtered total for that query; sibling badges must follow one consistent workspace model (shared filter context **or** dedicated scope totals — pick one model and apply it uniformly).
3. Assign `AppTabCountTone` per urgency: use `warning` / `danger` only for queues that need attention; use `info` for non-urgent scopes unless a test-documented product exception justifies otherwise (`tabs.mdc`).
4. Keep table trailing action order exactly: **Filters → Settings → Export → Print → context** (Schedule, Register). Use shared labels that resolve to `Filters`, `Settings`, `Export`, and `Print` (`tables.mdc`, `printing.mdc`). Prefer `commonFiltersActionLabel` / `commonPrintActionLabel` (or equivalent keys that resolve to those strings).
5. Extend shared list-table / search-bar support so Reception can mount **Print** after Export when printing is allowed for that table. Print must open a shared preview-first path (`showAppPrintPreviewDialog` and/or `PrintDocumentTemplates` / existing OPD summary preview stack) with section and column options aligned to exportable fields (`printing.mdc`, `tables.mdc`). Omit Print when unauthorized; do not show disabled Print.
6. Gate Export with an explicit Reception (or shared desk) permission check via `canExport`; omit Export when unauthorized (`tables.mdc`).
7. Keep Schedule / Register as context actions after Print; omit without ∩ `patient:write`. Preserve in-desk Schedule shell and Register → patient detail flow; reuse shared fields/forms (`forms.mdc`); hide tenant/facility/session context fields.
8. Ensure Schedule / Appointment / Queue / Flow / Follow-up / Payment-gate dialogs use **generic titles**, flat bodies, pinned footers, and maximized defaults per `dialogs.mdc`. Identity stays in the body.
9. When Reception opens Flow Actions, keep clinical / vitals / billing stripped. Rename any Flow Actions print trigger used from Reception so the **trigger label is exactly `Print`** (preview title may stay generic `Print preview`) (`printing.mdc`).
10. Cover loading, empty, error, success, and retry for workspace load, tab switch, filter apply, export, and print. Synchronize table + all affected tab counts after mutations (`tabs.mdc`, `prompt.mdc`).
11. Preserve deep-link `section` / `search` / `flowId` / `action` behavior and `syncWorkspaceLocation` in-desk URL sync (`screens.mdc`).

## Constraints

- Prefer extending `AppListTable` / `AppSearchBar` / shared printing once; do not invent a Reception-only Print button row.
- Do not add nested feature routes for Schedule / Register / hubs.
- Do not mount cashier Receive payment on shared Reception chrome.
- Do not restate rule text in code comments; reference the rule file name when a justified exception is unavoidable.

## Acceptance Criteria

- [ ] Every visible tab shows a count badge sourced per Requirements 2–3; tones match the urgency policy.
- [ ] Toolbar order on every printable table tab is Filters → Settings → Export → Print → Schedule → Register (with unauthorized controls omitted).
- [ ] Print always opens shared preview before device print; trigger label is `Print`.
- [ ] Export is omitted when the export gate denies; present when allowed.
- [ ] Unauthorized tabs and strip actions are absent (not disabled).
- [ ] Dialogs opened from shared chrome keep generic titles and reuse shared form/dialog primitives.
- [ ] Mutations refresh table rows and all visible tab counts that can change.
- [ ] `tabs/01-reception/00-shared-chrome.md` updated to match.

## Verification

- Widget / golden or integration tests for toolbar order and omit-when-unauthorized Export / Print / Schedule / Register.
- Unit or controller tests for authoritative counts and filtered active-tab badge.
- Manual: light/dark + narrow viewport strip overflow; print preview section/column toggles update live preview.
- Regression: deep links `action=register|schedule|walk_in` and `section=` still open the correct in-desk surfaces.

## Relevant Files

- `tabs/01-reception/00-shared-chrome.md`
- `tabs/01-reception/99-convention-gaps.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/components/app_tab_strip.dart`
- `frontend/lib/shared/printing/`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_print_summary_dialog.dart`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/screens.mdc`
