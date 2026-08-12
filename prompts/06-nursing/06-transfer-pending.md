# Nursing Transfer Pending tab — rule compliance

## Context

Make the Transfer Pending desk section fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/06-nursing/06-transfer-pending.md`. Apply shared chrome fixes from `prompts/06-nursing/00-shared-chrome.md` first when this tab depends on them (counts, Print, Export gate, tones, shared filter labels).

## Requirements

1. Keep strip label `nursingScopeTransferPendingLabel`, deep-link `section` per inventory, and omit the tab when gate denies access (`NursingTransferPendingAtomPermissions.tab` = `nursingWorkspaceReadRequirement`) — never show a disabled placeholder (`tabs.mdc`). Align `desk section` / query helpers with `tabs/06-nursing/00-overview.md`.
2. Badge count must be the authoritative total for this tab’s scope (`state.transferPendingCount` (null when 0)). When Filters/search/date narrow the active tab, the **active** badge must reflect the filtered total (`tabs.mdc`). Stop using painted-row length alone when a total is available or can be derived from the same filter model.
3. Use `AppTabCountTone.warning` as inventoried, or escalate to `danger` only when product policy requires (`tabs.mdc`).
4. Toolbar order: **Filters → Settings → Export → Shift context** — normalize shared labels to `Filters`, `Settings`, `Export`, and `Print` when those controls apply (`tables.mdc`, `printing.mdc`).
5. Mount table Print with preview-first shared printing and column/section options aligned to this tab’s exportable fields. Omit Print/Export/context actions when unauthorized (`printing.mdc`, `tables.mdc`).
6. Keep default visible columns at **5** unless a justified exception is recorded (always-visible keys / regulatory minimums / explicit default set in code + test). Settings must list every available column; Reset restores the default set (`tables.mdc`).
7. Advanced filters must be comprehensive for this tab’s domain and edit the **same** filter model as the table and active count. Footer actions: **Clear filters** → **Apply filters** → **Close** (`tabs.mdc`, `tables.mdc`, `dialogs.mdc`).
8. Preserve in-desk actions for this surface via shared dialogs/forms; omit unauthorized actions (`dialogs.mdc`, `forms.mdc`, `screens.mdc`). Inventoried dialogs to keep compliant: Patient detail + complementary.
9. Reuse shared form fields and validators; hide tenant/facility/session context the operator already knows; reset dependent fields when parents change (`forms.mdc`).
10. Any print entry from this tab (toolbar or nested hub) must use trigger label `Print` and shared preview (`printing.mdc`).
11. Cover empty, loading, error/retry, success, and validation feedback. Refresh table + all affected tab counts after mutations (`prompt.mdc`, `tabs.mdc`).

## Constraints

- Do not fork parallel table/tab/dialog/print chrome when a shared path exists or can be extended.
- Do not add nested feature routes for multi-step work on this tab.
- Do not invent columns that duplicate the same fact (`tables.mdc`).
- Do not broaden into unrelated modules except allowed ownership handoffs (`screens.mdc`).

## Acceptance Criteria

- [x] Tab count matches authoritative / filtered rules in Requirements 2–3.
- [x] Toolbar order and labels match Requirement 4; Print preview opens before print when Print applies.
- [x] Default column policy satisfies Requirement 6; Settings exposes all columns.
- [x] Advanced filters share the table/count model and include Close (`Requirement 7`).
- [x] Unauthorized tab and actions are absent (not disabled).
- [x] Dialogs/forms keep generic titles and shared field reuse.
- [x] `tabs/06-nursing/06-transfer-pending.md` updated to match.

## Verification

- Tests: tab omit gate; filtered/authoritative count; toolbar Print/Export presence matrix; omit-when-unauthorized for strip and row actions.
- Manual: primary happy-path mutation(s) remain in-desk; light/dark + narrow viewport.

## Relevant Files

- `tabs/06-nursing/06-transfer-pending.md`
- `prompts/06-nursing/00-shared-chrome.md`
- `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`
- `frontend/lib/features/nursing/presentation/nursing_access.dart`
- `frontend/test/features/nursing/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
