# Pharmacy Queue tab — rule compliance

## Context

Make the Queue desk section fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/12-pharmacy/01-queue.md`. Apply shared chrome fixes from `prompts/12-pharmacy/00-shared-chrome.md` first when this tab depends on them (counts, Print, Export gate, tones, shared filter labels).

## Requirements

1. Keep strip label `pharmacyDeskNewOrdersLabel`, deep-link `queue`, and omit the tab when gate denies access (`PharmacyReadyAtomPermissions.tab` = ∩ `pharmacy:read` + `pharmacy-dispensing`) — never show a disabled placeholder (`tabs.mdc`). Align `PharmacyDeskSection` / query helpers with `tabs/12-pharmacy/00-overview.md`.
2. Badge count must be the authoritative total for this tab’s scope (`summary.orderedQueue` (active tab may use filtered membership)). When Filters/search/date narrow the active tab, the **active** badge must reflect the filtered total (`tabs.mdc`). Stop using painted-row length alone when a total is available or can be derived from the same filter model.
3. Use `AppTabCountTone.warning` as inventoried, or escalate to `danger` only when product policy requires (`tabs.mdc`).
4. Target trailing order Filters → Settings → Export → Print → context actions. Inventory today: **Filters → Settings → Open reports? → Walk-in order?**. Normalize shared labels to `Filters`, `Settings`, `Export`, and `Print` when those controls apply; keep inventoried context actions after Print (`tables.mdc`, `printing.mdc`).
5. Inventory shows table Print **absent**. Add preview-first Print after Export on this list table (or record a justified tested product exception if Print must stay off). Omit Print/Export when unauthorized (`printing.mdc`, `tables.mdc`).
6. Keep default visible columns at **5** unless a justified exception is recorded (always-visible keys / regulatory minimums / explicit default set in code + test). Settings must list every available column; Reset restores the default set (`tables.mdc`).
7. Advanced filters must be comprehensive for this tab’s domain and edit the **same** filter model as the table and active count. Footer actions: **Clear filters** → **Apply filters** → **Close** (`tabs.mdc`, `tables.mdc`, `dialogs.mdc`).
8. Preserve row-select → detail/actions hub with **generic titles**; keep nested mutations in-desk via shared dialogs/forms; omit unauthorized nested actions (`dialogs.mdc`, `forms.mdc`, `screens.mdc`). Inventoried dialogs to keep compliant: Order detail; Dispense / Dispense all / batch; Attest; Return; Cancel order / cancel item; Walk-in order; Record payment; Print instructions / invoice / batch.
9. Reuse shared form fields and validators; hide tenant/facility/session context the operator already knows; reset dependent fields when parents change (`forms.mdc`).
10. Any print entry from this tab (toolbar or nested hub) must use trigger label `Print` and shared preview (`printing.mdc`).
11. Cover empty, loading, error/retry, success, and validation feedback. Refresh table + all affected tab counts after mutations (`prompt.mdc`, `tabs.mdc`).

## Constraints

- Do not fork parallel table/tab/dialog/print chrome when a shared path exists or can be extended.
- Do not add nested feature routes for multi-step work on this tab.
- Do not invent columns that duplicate the same fact (`tables.mdc`).
- Do not broaden into unrelated modules except allowed ownership handoffs (`screens.mdc`).

## Acceptance Criteria

- [ ] Tab count matches authoritative / filtered rules in Requirements 2–3.
- [ ] Toolbar order and labels match Requirement 4; Print preview opens before print when Print applies.
- [ ] Default column policy satisfies Requirement 6; Settings exposes all columns.
- [ ] Advanced filters share the table/count model and include Close (`Requirement 7`).
- [ ] Unauthorized tab and actions are absent (not disabled).
- [ ] Dialogs/forms keep generic titles and shared field reuse.
- [ ] `tabs/12-pharmacy/01-queue.md` updated to match.

## Verification

- Tests: tab omit gate; filtered/authoritative count; toolbar Print/Export presence matrix; omit-when-unauthorized for strip and row actions.
- Manual: primary happy-path mutation(s) remain in-desk; light/dark + narrow viewport.

## Relevant Files

- `tabs/12-pharmacy/01-queue.md`
- `prompts/12-pharmacy/00-shared-chrome.md`
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`
- `frontend/test/features/pharmacy/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
