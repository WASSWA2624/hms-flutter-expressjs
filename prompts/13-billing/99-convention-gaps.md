# Billing convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/13-billing/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Billing **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. Close this inventory gap: Queue `AppListTable` does **not** mount Export or table Print; print/download lives on detail (invoice/receipt/claim/approval) and Price book list Print.
2. Close this inventory gap: Filters button uses `billingFiltersLabel` rather than always `commonFiltersActionLabel` (Price book uses common Filters label).
3. Close this inventory gap: Trailing actions are **owner-tab exclusive** (Charge → Open work; Issue all → To issue; Close day/shift → Collect) — intentional product split, not a missing control on other tabs.
4. Close this inventory gap: `BillingQueueType.overdue` remains in the enum and atom map but is normalized to Collect + overdue filter (not a desk tab).

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

19. After fixes, rewrite `tabs/13-billing/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
20. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, filter/footer labels).

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
- [x] `tabs/13-billing/99-convention-gaps.md` shows no open required gaps.
- [x] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/billing/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/13-billing/99-convention-gaps.md`
- `tabs/13-billing/00-shared-chrome.md`
- `tabs/13-billing/01-open-work.md`
- `tabs/13-billing/02-to-issue.md`
- `tabs/13-billing/03-collect-due.md`
- `tabs/13-billing/04-open-claims.md`
- `tabs/13-billing/05-need-approval.md`
- `tabs/13-billing/06-price-book.md`
- `prompts/13-billing/00-shared-chrome.md`
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/billing/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
