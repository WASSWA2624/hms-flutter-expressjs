# Nursing convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/06-nursing/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Nursing **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. Close this inventory gap: Route entry vs comments/tests — live catalog / `AppRoutes.nursing` = ∩ `nursing:read` + module; comments/tests still describe ∪ clinical|patient|last_office|operations:read.
2. Close this inventory gap: Dual read vocabulary — shell/catalog uses `nursing:read`; tab/list chrome uses ∪ `clinical:read` \| `patient:read`.
3. Close this inventory gap: No worklist Print — print only from patient detail (`printing.mdc` / `tables.mdc` toolbar Print).
4. Close this inventory gap: No dedicated Handover toolbar — only Shift context + tab / next-action / detail.
5. Close this inventory gap: Export ungated in `NursingWorklistPanel` (table defaults; no `evidence:export`-style nursing gate).
6. Close this inventory gap: `assignedWard` scope filter is a no-op in entity `matchesScope` (always true) despite ABAC ward comments.
7. Close this inventory gap: Handover tab count uses global pending handovers, not scoped worklist length alone.
8. Close this inventory gap: Urgent / Medication due / Transfer pending atom classes omit `billingPanel`/`openBilling`, while shared detail can still show billing.
9. Close this inventory gap: Transfer has no `panel=` deep link.
10. Close this inventory gap: `openIcu` / `navigation` = empty `AccessRequirement()` when mounted.
11. Close this inventory gap: Responsible nurse column is synthetic summary text, not a real assignee field.
12. Close this inventory gap: Count badges omit `0` (`_tabCountOrNull`) — empty scopes hide the badge rather than showing explicit `0` (`tabs.mdc` prefers explicit 0 when meaningful).

### tabs.mdc

13. Replace client `items.length` / painted-page badge sources with authoritative totals (workspace summary / server `totalItemCount` / controller totals) wherever a total is available.
14. Define one sibling-count model for this desk and apply it on every tab: either (a) each tab’s scope total under the **same** shared filter/search context, or (b) each tab’s dedicated unfiltered scope total from a workspace summary. Do not mix filtered page length on one tab with raw loaded length on another.
15. When the active tab’s filters/search change, refresh that tab’s badge to the filtered total and refresh any sibling badges required by the chosen model (`tabs.mdc` sync rules).
16. Set count tones explicitly: `warning`/`danger` only for attention queues; other tabs default to `info` unless a test-documented exception applies.

### tables.mdc

17. Extend shared `AppListTable` / search trailing actions so **Print** can mount after Export when printing is allowed. Wire this desk’s printable tables to that API.
18. Ensure trailing order is exactly Filters → Settings → Export → Print → context actions on every printable table.
19. Add Export authorization via `canExport` (omit when denied); prefer an explicit ∩ `evidence:export` (or documented export atom) in the feature access map.
20. Normalize default visible column counts to prefer **5**, or record justified exceptions per tab in tests.
21. Confirm Advanced filters footers/labels and Table Settings footers match shared copy (`Filters` / `Advanced filters`; `Clear filters` / `Apply filters` / `Close`; `Reset columns` / `Apply columns` / `Close`).

### printing.mdc

22. Every Print trigger (table toolbar and nested hubs opened from this desk) must use the label **`Print`**, not content-specific strings.
23. Every Print path must open shared preview before device print, with selectable sections/columns/fields and live preview updates; disable final Print when selection yields an empty document.
24. Prefer `showAppPrintPreviewDialog` / `AppPrintPreview*` / `PrintDocumentTemplates` — extend shared preview helpers rather than forking.

### dialogs.mdc / forms.mdc / screens.mdc

25. Audit feature-owned and wrapper dialogs for generic titles, flat layout, no nested `AppCollapsibleSection`, maximized defaults, and shared field reuse; fix any violations found during remediation.
26. Keep flows in-desk; no nested feature routes for desk tasks; only allowed ownership handoffs per `screens.mdc`.

### Program hygiene

27. After fixes, rewrite `tabs/06-nursing/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
28. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, filter/footer labels).

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
- [ ] `tabs/06-nursing/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/nursing/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/06-nursing/99-convention-gaps.md`
- `tabs/06-nursing/00-shared-chrome.md`
- `tabs/06-nursing/01-all.md`
- `tabs/06-nursing/02-assigned-ward.md`
- `tabs/06-nursing/03-urgent.md`
- `tabs/06-nursing/04-medication-due.md`
- `tabs/06-nursing/05-handover-pending.md`
- `tabs/06-nursing/06-transfer-pending.md`
- `tabs/06-nursing/07-discharge-pending.md`
- `prompts/06-nursing/00-shared-chrome.md`
- `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/nursing/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
