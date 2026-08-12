# OPD convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/03-opd/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming OPD **100%** rule compliance.

## Requirements

### Inventory residual gaps (closed)

1. ~~Table Print absent~~ — board + Follow-ups mount preview-first Print after Export (`enablePrint` / `printOpdWorkspaceList`).
2. ~~All-tab count authority~~ — All badge uses `summaryCounts.allOpdPatients` (fallback combined length); filtered when active + narrowed.
3. ~~Follow-ups Filters omitted~~ — `FollowUpWorklistPanel` hosted with `showAdvancedFilterButton: true` + date filter + Close parity.
4. ~~Export RBAC~~ — `opdWorkspaceExportRequirement` ∩ `evidence:export`; `canExportOpdWorkspace` omits when denied.
5. ~~Empty unauthorized workspace~~ — no board tabs → forbidden `AppStateView` (not `SizedBox.shrink()`).

### tabs.mdc

6. Authoritative totals from workspace summary / page `totalItemCount` / follow-up provider (not painted-page length alone).
7. Sibling-count model: dedicated unfiltered scope totals; active tab uses filtered membership when search/advanced filters narrow.
8. Active-tab filter/search changes refresh that badge; siblings keep scope totals.
9. Count tones: `warning` for Arrivals/Queue/Triage/Active; `info` for All/Follow-ups.

### tables.mdc

10. Shared `AppListTable` Print API wired for board + Follow-ups.
11. Trailing order Filters → Settings → Export → Print → context (Start OPD on board; absent on Follow-ups).
12. Export via `canExport` + ∩ `evidence:export`.
13. Default visible columns prefer **5** (Queue Next action unmounted by design).
14. Advanced filters / Settings footers use shared Clear/Apply/Close (and column Reset/Apply/Close) copy.

### printing.mdc

15. Print triggers use `commonPrintActionLabel` → `Print` (table + Flow Actions).
16. Preview-first shared flow; empty selection disables final Print.
17. `printOpdWorkspaceList` / clinical summary via shared preview templates.

### dialogs.mdc / forms.mdc / screens.mdc

18. Shared hubs keep generic titles, flat layout, pinned footers, maximized defaults.
19. Flows stay in-desk; no nested feature routes for desk tasks.

### Program hygiene

20. `tabs/03-opd/99-convention-gaps.md` residual is **None**; per-tab inventories refreshed.
21. Regression tests under `frontend/test/features/opd/` cover count authority, tones, Export/Print omit, prefer-5, filter footers.

## Constraints

- Shared primitive changes must remain reusable by other workspaces; do not hard-code feature-only Print chrome inside `AppListTable` without a clean API.
- Do not treat inventory “intentional omissions” as compliance when rules require Filters/Print/date/counts—record a justified tested exception or implement the required control.
- Optional enhancements outside the gap list stay out of this prompt.

## Acceptance Criteria

- [x] Every residual gap listed in Requirements (Inventory residual gaps) is closed or recorded as a justified, tested product exception.
- [x] tabs.mdc count/tone/sync requirements verified.
- [x] tables.mdc Print/Export/column/filter-footer requirements verified.
- [x] printing.mdc Print label + preview-first + shared templates verified.
- [x] dialog/form/screen boundaries hold.
- [x] `tabs/03-opd/99-convention-gaps.md` shows no open required gaps.
- [x] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/opd/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/03-opd/99-convention-gaps.md`
- `tabs/03-opd/00-shared-chrome.md`
- `tabs/03-opd/01-all.md`
- `tabs/03-opd/02-arrivals.md`
- `tabs/03-opd/03-queue.md`
- `tabs/03-opd/04-triage.md`
- `tabs/03-opd/05-active.md`
- `tabs/03-opd/06-follow-ups.md`
- `prompts/03-opd/00-shared-chrome.md`
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/opd/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
