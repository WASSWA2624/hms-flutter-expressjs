# Pharmacy convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/12-pharmacy/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Pharmacy **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. Close this inventory gap: Order desk `AppListTable` does **not** mount Export or table Print; print is detail/instructions/batch/invoice helper-driven.
2. Close this inventory gap: Catalog formulary/selection tables explicitly set `enableExport: false`.
3. Close this inventory gap: Filters button label on orders uses `pharmacyQueueFilterLabel` (not always `commonFiltersActionLabel`).
4. Close this inventory gap: Stock-alert desks reuse Catalog → Inventory rather than a separate alert-only table.

### tabs.mdc

5. Replace client `items.length` / painted-page badge sources with authoritative totals (workspace summary / server `totalItemCount` / controller totals) wherever a total is available.
6. Define one sibling-count model for this desk and apply it on every tab: either (a) each tab’s scope total under the **same** shared filter/search context, or (b) each tab’s dedicated unfiltered scope total from a workspace summary. Do not mix filtered page length on one tab with raw loaded length on another.
7. When the active tab’s filters/search change, refresh that tab’s badge to the filtered total and refresh any sibling badges required by the chosen model (`tabs.mdc` sync rules).
8. Set count tones explicitly: `warning`/`danger` only for attention queues; other tabs default to `info` unless a test-documented exception applies.

### tables.mdc

9. Extend shared `AppListTable` / search trailing actions so **Print** can mount after Export when printing is allowed. Wire this desk’s printable tables to that API.
10. Ensure trailing order is exactly Filters → Settings → Export → Print → context actions on every printable table.
11. Add Export authorization via `canExport` (omit when denied); prefer an explicit ∩ `evidence:export` (or documented export atom) in the feature access map.
12. Normalize default visible column counts to prefer **5**, or record justified exceptions per tab in tests.
13. Confirm Advanced filters footers/labels and Table Settings footers match shared copy (`Filters` / `Advanced filters`; `Clear filters` / `Apply filters` / `Close`; `Reset columns` / `Apply columns` / `Close`).

### printing.mdc

14. Every Print trigger (table toolbar and nested hubs opened from this desk) must use the label **`Print`**, not content-specific strings.
15. Every Print path must open shared preview before device print, with selectable sections/columns/fields and live preview updates; disable final Print when selection yields an empty document.
16. Prefer `showAppPrintPreviewDialog` / `AppPrintPreview*` / `PrintDocumentTemplates` — extend shared preview helpers rather than forking.

### dialogs.mdc / forms.mdc / screens.mdc

17. Audit feature-owned and wrapper dialogs for generic titles, flat layout, no nested `AppCollapsibleSection`, maximized defaults, and shared field reuse; fix any violations found during remediation.
18. Keep flows in-desk; no nested feature routes for desk tasks; only allowed ownership handoffs per `screens.mdc`.

### Program hygiene

19. After fixes, rewrite `tabs/12-pharmacy/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
20. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, filter/footer labels).

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
- [ ] `tabs/12-pharmacy/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/pharmacy/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/12-pharmacy/99-convention-gaps.md`
- `tabs/12-pharmacy/00-shared-chrome.md`
- `tabs/12-pharmacy/01-queue.md`
- `tabs/12-pharmacy/02-in-progress.md`
- `tabs/12-pharmacy/03-pending-payment.md`
- `tabs/12-pharmacy/04-completed.md`
- `tabs/12-pharmacy/05-cancelled.md`
- `tabs/12-pharmacy/06-all-orders.md`
- `tabs/12-pharmacy/07-catalog.md`
- `tabs/12-pharmacy/08-suppliers.md`
- `tabs/12-pharmacy/09-near-expiry.md`
- `tabs/12-pharmacy/10-expired.md`
- `tabs/12-pharmacy/11-low-stock.md`
- `tabs/12-pharmacy/12-out-of-stock.md`
- `prompts/12-pharmacy/00-shared-chrome.md`
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/pharmacy/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
