# Admin setup Departments tab — rule compliance

## Context

Make the Departments desk section fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/20-admin-setup/03-departments.md`. Apply shared chrome fixes from `prompts/20-admin-setup/00-shared-chrome.md` first when this tab depends on them (counts, Print, Export gate, tones, shared filter labels).

## Requirements

1. Keep strip label `tenantFacilityWizardStepDepartments`, deep-link `departments`, and omit the tab when gate denies access (facility\|tenant manage) — never show a disabled placeholder (`tabs.mdc`). Align `TenantFacilitySetupDeskSection` / query helpers with `tabs/20-admin-setup/00-overview.md`.
2. Badge count must be the authoritative total for this tab’s scope (**none**). When Filters/search/date narrow the active tab, the **active** badge must reflect the filtered total (`tabs.mdc`). Stop using painted-row length alone when a total is available or can be derived from the same filter model.
3. Use an urgency-appropriate `AppTabCountTone` (default `info` unless product-justified `warning`/`danger` is documented in test) (`tabs.mdc`).
4. Toolbar order: **Filters → Settings → Export → Print → context** — normalize shared labels to `Filters`, `Settings`, `Export`, and `Print` when those controls apply (`tables.mdc`, `printing.mdc`).
5. Mount table Print with preview-first shared printing and column/section options aligned to this tab’s exportable fields. Omit Print/Export/context actions when unauthorized (`printing.mdc`, `tables.mdc`).
6. Keep default visible columns at **5** unless a justified exception is recorded (always-visible keys / regulatory minimums / explicit default set in code + test). Settings must list every available column; Reset restores the default set (`tables.mdc`).
7. Advanced filters must be comprehensive for this tab’s domain and edit the **same** filter model as the table and active count. Footer actions: **Clear filters** → **Apply filters** → **Close** (`tabs.mdc`, `tables.mdc`, `dialogs.mdc`).
8. Preserve in-desk actions for this surface via shared dialogs/forms; omit unauthorized actions (`dialogs.mdc`, `forms.mdc`, `screens.mdc`). Inventoried dialogs to keep compliant: Details department_details_dialog.dart; Similarity department_similarity_dialog.dart.
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
- [ ] `tabs/20-admin-setup/03-departments.md` updated to match.

## Verification

- Tests: tab omit gate; filtered/authoritative count; toolbar Print/Export presence matrix; omit-when-unauthorized for strip and row actions.
- Manual: primary happy-path mutation(s) remain in-desk; light/dark + narrow viewport.

## Relevant Files

- `tabs/20-admin-setup/03-departments.md`
- `prompts/20-admin-setup/00-shared-chrome.md`
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`

- `frontend/test/features/tenant_facility/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
