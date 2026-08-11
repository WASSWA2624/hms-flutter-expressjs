# Reception convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/01-reception/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Reception **100%** rule compliance.

## Requirements

### tabs.mdc

1. Replace client `items.length` badge sources on Appointments, Desk queue, High priority, Active visits, and Payment gate with authoritative totals (workspace summary / server `totalItemCount` / controller totals). Follow-ups already prefers `totalCount`—keep that pattern and extend it.
2. Define one sibling-count model for Reception and apply it on every tab: either (a) each tab’s scope total under the **same** shared filter/search context, or (b) each tab’s dedicated unfiltered scope total from a workspace summary. Do not mix filtered page length on one tab with raw loaded length on another.
3. When the active tab’s filters/search change, refresh that tab’s badge to the filtered total and refresh any sibling badges required by the chosen model (`tabs.mdc` sync rules).
4. Set count tones explicitly: `warning`/`danger` only for attention queues (Desk queue, High priority; Active visits / Payment gate only if justified in tests); other tabs default to `info`.

### tables.mdc

5. Extend shared `AppListTable` / search trailing actions so **Print** can mount after Export when printing is allowed. Wire Reception tables to that API.
6. Ensure trailing order is exactly Filters → Settings → Export → Print → context actions on every Reception table that allows print.
7. Add Reception Export authorization via `canExport` (omit when denied).
8. Normalize default visible column counts to prefer **5**, or record justified exceptions per tab in tests.
9. Confirm Advanced filters footers/labels and Table Settings footers match shared copy (`Clear filters` / `Apply filters` / `Close`; `Reset columns` / `Apply columns` / `Close`).

### printing.mdc

10. Every Reception Print trigger (table toolbar and Flow Actions entry points opened from Reception) must use the label **`Print`** (e.g. `commonPrintActionLabel`), not `Print summary` / content-specific strings.
11. Every Print path must open shared preview before device print, with selectable sections/columns/fields and live preview updates; disable final Print when selection yields an empty document.
12. Prefer `showAppPrintPreviewDialog` / `AppPrintPreview*` / `PrintDocumentTemplates` — extend shared OPD summary preview if needed rather than forking.

### dialogs.mdc / forms.mdc / screens.mdc

13. Audit Reception-owned and wrapper dialogs for generic titles, flat layout, no nested `AppCollapsibleSection`, maximized defaults, and shared field reuse; fix any violations found during remediation.
14. Keep Payment gate free of cashier collect UI; keep flows in-desk; no nested feature routes for desk tasks.

### Program hygiene

15. After fixes, rewrite `tabs/01-reception/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
16. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, Follow-ups filters present, Payment gate date filter present).

## Constraints

- Shared primitive changes must remain reusable by other workspaces; do not hard-code Reception-only Print chrome inside `AppListTable` without a clean API.
- Do not treat inventory “intentional omissions” as compliance; this program removes them where rules require Filters/Print/date/counts.
- Optional enhancements outside the gap list stay out of this prompt.

## Acceptance Criteria

- [ ] Requirements 1–4 verified: authoritative counts, one sibling model, filtered active badge, tone policy.
- [ ] Requirements 5–9 verified: Print after Export, Export gated, column defaults, shared filter/settings copy.
- [ ] Requirements 10–12 verified: Print label + preview-first + shared templates.
- [ ] Requirements 13–14 verified: dialog/form/screen boundaries hold; no cashier on Payment gate.
- [ ] `tabs/01-reception/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Requirement 16 exist and pass.

## Verification

- Run `frontend/test/features/reception/` plus any new shared `app_list_table` print/export tests.
- Code search: no Reception toolbar missing Print when policy allows; no `opdPrintSummaryAction` visible string from Reception entry points; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user on all six tabs for omit-when-unauthorized Export/Print/Schedule/Register/Filters.

## Relevant Files

- `tabs/01-reception/99-convention-gaps.md`
- `tabs/01-reception/00-shared-chrome.md`
- `tabs/01-reception/01-appointments.md`
- `tabs/01-reception/02-desk-queue.md`
- `tabs/01-reception/03-high-priority.md`
- `tabs/01-reception/04-active-visits.md`
- `tabs/01-reception/05-follow-ups.md`
- `tabs/01-reception/06-payment-gate.md`
- `prompts/01-reception/00-shared-chrome.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_print_summary_dialog.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/prompt.mdc`
