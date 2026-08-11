# Patients registry convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/02-patients/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Patients registry **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. Close this inventory gap: Table Print absent (`tables.mdc` / `printing.mdc`) — toolbar has Export but no preview-first Print after Export on any registry tab.
2. Close this inventory gap: Filters labels (`tables.mdc`) — uses `patientsAdvancedFiltersAction` / `patientsAdvancedFiltersTitle` instead of shared `Filters` / `Advanced filters` (`commonFiltersActionLabel` / `commonAdvancedFiltersTitle`).
3. Close this inventory gap: Advanced filters footer (`tables.mdc` / `dialogs.mdc`) — Clear + Apply only; no **Close** (`commonCloseActionLabel`).
4. Close this inventory gap: Active-tab filtered counts (`tabs.mdc`) — strip badges always use overview scope totals; do not switch to filtered membership totals when search/advanced filters narrow the active tab.
5. Close this inventory gap: Export RBAC (`tables.mdc`) — Export mounts with the table; no explicit ∩ `evidence:export` atom in `patient_registry_access.dart` (unlike Reception desk export gate).

### tabs.mdc

6. Replace client `items.length` / painted-page badge sources with authoritative totals (workspace summary / server `totalItemCount` / controller totals) wherever a total is available.
7. Define one sibling-count model for this desk and apply it on every tab: either (a) each tab’s scope total under the **same** shared filter/search context, or (b) each tab’s dedicated unfiltered scope total from a workspace summary. Do not mix filtered page length on one tab with raw loaded length on another.
8. When the active tab’s filters/search change, refresh that tab’s badge to the filtered total and refresh any sibling badges required by the chosen model (`tabs.mdc` sync rules).
9. Set count tones explicitly: `warning`/`danger` only for attention queues; other tabs default to `info` unless a test-documented exception applies.

### tables.mdc

10. Extend shared `AppListTable` / search trailing actions so **Print** can mount after Export when printing is allowed. Wire this desk’s printable tables to that API.
11. Ensure trailing order is exactly Filters → Settings → Export → Print → context actions on every printable table.
12. Add Export authorization via `canExport` (omit when denied); prefer an explicit ∩ `evidence:export` (or documented export atom) in the feature access map.
13. Normalize default visible column counts to prefer **5**, or record justified exceptions per tab in tests.
14. Confirm Advanced filters footers/labels and Table Settings footers match shared copy (`Filters` / `Advanced filters`; `Clear filters` / `Apply filters` / `Close`; `Reset columns` / `Apply columns` / `Close`).

### printing.mdc

15. Every Print trigger (table toolbar and nested hubs opened from this desk) must use the label **`Print`**, not content-specific strings.
16. Every Print path must open shared preview before device print, with selectable sections/columns/fields and live preview updates; disable final Print when selection yields an empty document.
17. Prefer `showAppPrintPreviewDialog` / `AppPrintPreview*` / `PrintDocumentTemplates` — extend shared preview helpers rather than forking.

### dialogs.mdc / forms.mdc / screens.mdc

18. Audit feature-owned and wrapper dialogs for generic titles, flat layout, no nested `AppCollapsibleSection`, maximized defaults, and shared field reuse; fix any violations found during remediation.
19. Keep flows in-desk; no nested feature routes for desk tasks; only allowed ownership handoffs per `screens.mdc`.

### Program hygiene

20. After fixes, rewrite `tabs/02-patients/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
21. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, filter/footer labels).

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
- [ ] `tabs/02-patients/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/patients/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/02-patients/99-convention-gaps.md`
- `tabs/02-patients/00-shared-chrome.md`
- `tabs/02-patients/01-all.md`
- `tabs/02-patients/02-active.md`
- `tabs/02-patients/03-admitted.md`
- `tabs/02-patients/04-balance-due.md`
- `prompts/02-patients/00-shared-chrome.md`
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/patients/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
