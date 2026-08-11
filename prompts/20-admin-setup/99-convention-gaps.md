# Admin setup convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/20-admin-setup/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming Admin setup **100%** rule compliance.

## Requirements

### Inventory residual gaps

1. Close this inventory gap: No tab counts / tones on `AppTabStrip`.
2. Close this inventory gap: No feature `*_access.dart` / `AccessRequirement` atoms for Setup desk; gates are imperative `AppAccessPolicy` methods; catalog entry is ∩ `setup:read` + facility context while UI uses admin/`hr:write`/`isElevated`.
3. Close this inventory gap: Export mostly **ungated** (`AppListTable.enableExport` default true) — Reception uses ∩ `evidence:export`.
4. Close this inventory gap: No table Print / preview-first path on Setup desks.
5. Close this inventory gap: Wizard widget unused by desk; still in tree (`tenant_facility_setup_wizard.dart`).
6. Close this inventory gap: Deep-link only `section`/`tab` — no search/action query sync.

### tabs.mdc

7. Replace client `items.length` / painted-page badge sources with authoritative totals (workspace summary / server `totalItemCount` / controller totals) wherever a total is available.
8. Define one sibling-count model for this desk and apply it on every tab: either (a) each tab’s scope total under the **same** shared filter/search context, or (b) each tab’s dedicated unfiltered scope total from a workspace summary. Do not mix filtered page length on one tab with raw loaded length on another.
9. When the active tab’s filters/search change, refresh that tab’s badge to the filtered total and refresh any sibling badges required by the chosen model (`tabs.mdc` sync rules).
10. Set count tones explicitly: `warning`/`danger` only for attention queues; other tabs default to `info` unless a test-documented exception applies.

### tables.mdc

11. Extend shared `AppListTable` / search trailing actions so **Print** can mount after Export when printing is allowed. Wire this desk’s printable tables to that API.
12. Ensure trailing order is exactly Filters → Settings → Export → Print → context actions on every printable table.
13. Add Export authorization via `canExport` (omit when denied); prefer an explicit ∩ `evidence:export` (or documented export atom) in the feature access map.
14. Normalize default visible column counts to prefer **5**, or record justified exceptions per tab in tests.
15. Confirm Advanced filters footers/labels and Table Settings footers match shared copy (`Filters` / `Advanced filters`; `Clear filters` / `Apply filters` / `Close`; `Reset columns` / `Apply columns` / `Close`).

### printing.mdc

16. Every Print trigger (table toolbar and nested hubs opened from this desk) must use the label **`Print`**, not content-specific strings.
17. Every Print path must open shared preview before device print, with selectable sections/columns/fields and live preview updates; disable final Print when selection yields an empty document.
18. Prefer `showAppPrintPreviewDialog` / `AppPrintPreview*` / `PrintDocumentTemplates` — extend shared preview helpers rather than forking.

### dialogs.mdc / forms.mdc / screens.mdc

19. Audit feature-owned and wrapper dialogs for generic titles, flat layout, no nested `AppCollapsibleSection`, maximized defaults, and shared field reuse; fix any violations found during remediation.
20. Keep flows in-desk; no nested feature routes for desk tasks; only allowed ownership handoffs per `screens.mdc`.

### Program hygiene

21. After fixes, rewrite `tabs/20-admin-setup/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
22. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, filter/footer labels).

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
- [ ] `tabs/20-admin-setup/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `frontend/test/features/tenant_facility/` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/20-admin-setup/99-convention-gaps.md`
- `tabs/20-admin-setup/00-shared-chrome.md`
- `tabs/20-admin-setup/01-tenants.md`
- `tabs/20-admin-setup/02-facility.md`
- `tabs/20-admin-setup/03-departments.md`
- `tabs/20-admin-setup/04-units.md`
- `tabs/20-admin-setup/05-wards.md`
- `tabs/20-admin-setup/06-rooms.md`
- `tabs/20-admin-setup/07-beds.md`
- `tabs/20-admin-setup/08-roles.md`
- `tabs/20-admin-setup/09-permissions.md`
- `tabs/20-admin-setup/10-users.md`
- `tabs/20-admin-setup/11-clinical-catalog.md`
- `tabs/20-admin-setup/12-subscription-approvals.md`
- `tabs/20-admin-setup/13-subscription-activations.md`
- `prompts/20-admin-setup/00-shared-chrome.md`
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/features/tenant_facility/`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
