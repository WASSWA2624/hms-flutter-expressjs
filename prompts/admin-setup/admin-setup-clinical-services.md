# Refine Clinical Services nested catalogs

On `/admin/setup?section=clinical-services`, subordinate Radiology / Lab / Diagnoses, rename Diagnoses create copy, and infinite-scroll past the 100-row cap.

## Context

Nested catalog tabs share `AppTabStrip` with parent desk tabs. Lists use `limit: 100` with no append-on-scroll; switches feel slow. Diagnoses create says **Add service**; change to **Add diagnosis**. Keep Radiology **Create imaging test**, Lab **Add test** / **Add panel**, and Filter / Settings / Configure.

## Requirements

1. Restyle nested Radiology / Lab / Diagnoses as subordinate to the parent desk `AppTabStrip` (theme tokens; leave parent tabs unchanged).
2. Rename Diagnoses create action and create-dialog title to **Add diagnosis** (l10n); keep Edit / Delete / Configure.
3. Switch nested tabs without full-panel blocking; warm prior data when possible; show loading / empty / error / success only on the active catalog.
4. Wire all three `AppListTable`s to infinite scroll that appends until exhausted; reuse `AppListTablePaginationMode.infinite` and list contracts; keep scroll responsive.
5. Show mutate actions only when `canManageFacility || canManageTenant`; omit forbidden mutate UI.
6. After create / edit / delete, synchronize the active list in place.

## Constraints

Reuse routes, repositories, dialogs, RBAC, `AppListTable`, and theme tokens. No unrelated desk/wizard work. Mobile/tablet/desktop; light and dark.

## Acceptance Criteria

- Nested tabs clearly read as sub-tabs under Clinical Services.
- Diagnoses CTA/create title is **Add diagnosis**; Radiology/Lab labels unchanged.
- Nested switches feel immediate; feedback scoped to the active catalog.
- Scroll past 100 rows until exhausted on all three tables.
- Unauthorized users never see mutate actions; authorized mutations appear in-table.
- Check the route (three tabs, light/dark, narrow) and test infinite load plus Diagnoses copy.

## Relevant Files

- `facility_catalog_config_panel.dart`, `app_tab_strip.dart`, `app_list_table.dart`, `clinical_catalog_admin_dialogs.dart`, `app_en.arb`, catalog repositories, `screens/admin-setup-clinical-services.md`
