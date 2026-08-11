# Theater convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/08-theater/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Theater **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. Close this inventory gap: No table Print — `enablePrint` not set; no preview-first registry / Theater print path.
2. Close this inventory gap: Export ungated — default AppListTable Export without ∩ `evidence:export` / `canExport`.
3. Close this inventory gap: Toolbar order — Filters → Settings → Export → Schedule case (no Print slot).
4. Close this inventory gap: Default columns — **4** data columns (+ optional next-action), not prefer-5.
5. Close this inventory gap: Tab count authority — Scheduled / In theater / Recovery badges from **current page membership**, not dedicated unfiltered sibling totals.
6. Close this inventory gap: Empty unauthorized workspace — `SizedBox.shrink()` instead of forbidden `AppFailureStateView`.
7. Close this inventory gap: Recovery list vs count — tab applies `stage=POST_OP` only while `recoveryCount` includes `PACU_HANDOFF`.
8. Close this inventory gap: Follow-ups Filters/date off — host disables advanced filters and date filter.
9. Close this inventory gap: `theaterApplyFiltersAction` unused — Apply uses `opdApplyFiltersAction`.
10. Close this inventory gap: `keepPreviousDataDuringRefresh: false` — unlike Reception `true`.

### tabs.mdc

11. Replace client `items.length` / painted-page badge sources with authoritative totals (workspace summary / server `totalItemCount` / controller totals) wherever a total is available.
12. Define one sibling-count model for this desk and apply it on every tab: either (a) each tab’s scope total under the **same** shared filter/search context, or (b) each tab’s dedicated unfiltered scope total from a workspace summary. Do not mix filtered page length on one tab with raw loaded length on another.
13. When the active tab’s filters/search change, refresh that tab’s badge to the filtered total and refresh any sibling badges required by the chosen model (`tabs.mdc` sync rules).
14. Set count tones explicitly: `warning`/`danger` only for attention queues; other tabs default to `info` unless a test-documented exception applies.

### tables.mdc

15. Extend shared `AppListTable` / search trailing actions so **Print** can mount after Export when printing is allowed. Wire this desk’s printable tables to that API.
16. Ensure trailing order is exactly Filters → Settings → Export → Print → context actions on every printable table.
17. Add Export authorization via `canExport` (omit when denied); prefer an explicit ∩ `evidence:export` (or documented export atom) in the feature access map.
18. Normalize default visible column counts to prefer **5**, or record justified exceptions per tab in tests.
19. Confirm Advanced filters footers/labels and Table Settings footers match shared copy (`Filters` / `Advanced filters`; `Clear filters` / `Apply filters` / `Close`; `Reset columns` / `Apply columns` / `Close`).

### printing.mdc

20. Every Print trigger (table toolbar and nested hubs opened from this desk) must use the label **`Print`**, not content-specific strings.
21. Every Print path must open shared preview before device print, with selectable sections/columns/fields and live preview updates; disable final Print when selection yields an empty document.
22. Prefer `showAppPrintPreviewDialog` / `AppPrintPreview*` / `PrintDocumentTemplates` — extend shared preview helpers rather than forking.

### dialogs.mdc / forms.mdc / screens.mdc

23. Audit feature-owned and wrapper dialogs for generic titles, flat layout, no nested `AppCollapsibleSection`, maximized defaults, and shared field reuse; fix any violations found during remediation.
24. Keep flows in-desk; no nested feature routes for desk tasks; only allowed ownership handoffs per `screens.mdc`.

### Program hygiene

25. After fixes, rewrite `tabs/08-theater/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
26. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, filter/footer labels).

## Constraints

- Shared primitive changes must remain reusable by other workspaces; do not hard-code feature-only Print chrome inside `AppListTable` without a clean API.
- Do not treat inventory “intentional omissions” as compliance when rules require Filters/Print/date/counts—record a justified tested exception or implement the required control.
- Optional enhancements outside the gap list stay out of this prompt.

## Acceptance Criteria

- [ ] Every residual gap listed in Requirements (Inventory residual gaps) is closed or recorded as a justified, tested product exception.
- [ ] tabs.mdc count/tone/sync requirements verified.
- [ ] tables.mdc Print/Export/column/filter-footer requirements verified.
- [ ] printing.mdc Print label + preview-first + shared templates verified.
- [ ] dialog/form/screen boundaries hold.
- [ ] `tabs/08-theater/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/theater/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/08-theater/99-convention-gaps.md`
- `tabs/08-theater/00-shared-chrome.md`
- `tabs/08-theater/01-scheduled.md`
- `tabs/08-theater/02-in-theater.md`
- `tabs/08-theater/03-recovery.md`
- `tabs/08-theater/04-all.md`
- `tabs/08-theater/05-follow-ups.md`
- `prompts/08-theater/00-shared-chrome.md`
- `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/theater/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
