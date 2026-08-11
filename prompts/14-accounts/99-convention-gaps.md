# Accounts convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/14-accounts/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Accounts **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. Close this inventory gap: Open work lacks table `enableExport` / `enablePrint` while journals/approvals/gl/ledgers export; chart uses a custom Print trailing action instead of `AppListTable.enablePrint`.
2. Close this inventory gap: Approvals and GL omit date filter; Books omits advanced Filters entirely (chips only) — document as intentional, but uneven vs reception “Filters on all tabs” convention.
3. Close this inventory gap: Print helpers reuse `PrintDocumentTemplates.claimStatement` for journal/approval/GL/books/patient ledger packets (shared template name; Accounts-owned option panels).
4. Close this inventory gap: `accounts_gl_workspace_page.dart` is a re-export of the desk page — no separate GL route surface beyond `?section=gl` + dialog.
5. Close this inventory gap: Open work has no Export while sibling work-queue tabs do — flag if tables.mdc expects Export whenever list chrome is readable.

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

20. After fixes, rewrite `tabs/14-accounts/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
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
- [ ] `tabs/14-accounts/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/accounts/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/14-accounts/99-convention-gaps.md`
- `tabs/14-accounts/00-shared-chrome.md`
- `tabs/14-accounts/01-work.md`
- `tabs/14-accounts/02-journals.md`
- `tabs/14-accounts/03-approvals.md`
- `tabs/14-accounts/04-gl.md`
- `tabs/14-accounts/05-ledgers.md`
- `tabs/14-accounts/06-chart.md`
- `tabs/14-accounts/07-books.md`
- `prompts/14-accounts/00-shared-chrome.md`
- `frontend/lib/features/accounts/presentation/pages/accounts_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/accounts/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
