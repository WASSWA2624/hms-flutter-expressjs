# Claims convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/15-claims/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Claims **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. ~~Advanced Filters only on Settled~~ **Closed** — Filters on Authorizations / Active Claims / Settled (`claims_workspace_page.dart`; per-tab + workspace tests).
2. ~~Date filter disabled~~ **Justified exception** — `ClaimsQueueQuery` / work-items API have no date range (`enableDateFilter: false`; `claims_workspace_page_test.dart`).
3. ~~No table-level Export/Print~~ **Closed** — queue toolbar Export/Print ∩ `evidence:export`; preview-first via `printClaimsListTable` → `PrintDocumentTemplates.registry`.
4. ~~Insurance Setup count always 0~~ **Closed** — count omitted (`count: null`); catalog hub exception recorded + tested.

### tabs.mdc

5. Authoritative totals via workspace summary / `queue.totalItemCount` (`claimsSectionTabCount`).
6. Sibling model: dedicated unfiltered summary scope totals; active narrowed tab uses filtered `totalItemCount`.
7. Active badge refreshes with filter/search; siblings keep dedicated scope totals.
8. Tones: `warning` Authorizations + Active Claims; `info` Settled (+ Insurance Setup when counted).

### tables.mdc

9. Shared `AppListTable` Print mounts after Export when allowed.
10. Trailing order: Filters → Settings → Export → Print → context.
11. Export via `canExportClaimsWorkspace` ∩ `evidence:export` (omit when denied).
12. Default visible columns prefer **5** (Next omitted → promote Approved amount / Invoice).
13. Advanced filters / Settings footers use shared copy (`Filters`; `Clear filters` / `Apply filters` / `Close`; Settings labels).

### printing.mdc

14. Print trigger label `commonPrintActionLabel` (`Print`).
15. Preview-first via `PrintDocumentTemplates.registry` → `showAppPrintPreviewDialog`; empty selection disables final Print.
16. Shared helpers only — `claims_workspace_print_helpers.dart` (no forked preview chrome).

### dialogs.mdc / forms.mdc / screens.mdc

17. Feature dialogs keep generic titles / shared fields; no nested feature routes for desk tasks.
18. Flows stay in-desk; only allowed ownership handoffs (`screens.mdc`).

### Program hygiene

19. `tabs/15-claims/99-convention-gaps.md` residual list is **none** (+ justified exceptions); tab inventories match shipped behavior.
20. Regression coverage under `frontend/test/features/claims/` (counts, tones, toolbar, Print label, Export omit, filter footers, Insurance Setup omit).

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
- [x] `tabs/15-claims/99-convention-gaps.md` shows no open required gaps.
- [x] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/claims/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/15-claims/99-convention-gaps.md`
- `tabs/15-claims/00-shared-chrome.md`
- `tabs/15-claims/01-authorizations.md`
- `tabs/15-claims/02-active-claims.md`
- `tabs/15-claims/03-settled.md`
- `tabs/15-claims/04-insurance-setup.md`
- `prompts/15-claims/00-shared-chrome.md`
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/widgets/claims_scope_navigation.dart`
- `frontend/lib/features/claims/presentation/widgets/claims_workspace_print_helpers.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/claims/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
