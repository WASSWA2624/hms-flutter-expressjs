# Refine Clinical Services nested catalogs

On `/admin/setup?section=clinical-services`, subordinate Radiology / Lab / Diagnoses, rename Diagnoses create copy, and infinite-scroll past 100 rows.

## Context

Nested tabs share `AppTabStrip` with parent desk tabs. Lists use `limit: 100` with no append-on-scroll; switches feel slow. Diagnoses create says **Add service**; change to **Add diagnosis**. Keep Radiology **Create imaging test**, Lab **Add test** / **Add panel**, Filter / Settings / Configure.

## Requirements

1. Restyle nested Radiology / Lab / Diagnoses as subordinate to the parent desk `AppTabStrip` (theme tokens; leave parent unchanged).
2. Rename Diagnoses create action and create-dialog title to **Add diagnosis** (l10n); keep Edit / Delete / Configure.
3. Switch nested tabs without full-panel blocking; warm prior data; show loading / empty / error / success only on the active catalog.
4. Infinite-scroll all three tables until exhausted via `AppListTablePaginationMode.infinite`; keep scroll smooth.
5. Show mutate actions only when `canManageFacility || canManageTenant`; omit forbidden mutate UI.
6. After create / edit / delete, sync the active list in place.

## Constraints

Reuse routes, repositories, dialogs, RBAC, `AppListTable`, theme tokens. No unrelated desk/wizard work. Light/dark.

## Acceptance Criteria

- Nested tabs clearly read as sub-tabs; Diagnoses CTA/create is **Add diagnosis**; Radiology/Lab labels unchanged.
- Nested switches feel immediate; feedback scoped to active catalog; scroll past 100 until exhausted.
- Omit forbidden mutate UI; authorized mutations appear in-table.
- Check route (three tabs, light/dark, narrow); test infinite load and Diagnoses copy.

## Relevant Files

- `facility_catalog_config_panel.dart`, `app_tab_strip.dart`, `app_list_table.dart`, `clinical_catalog_admin_dialogs.dart`, `app_en.arb`, catalog repos
