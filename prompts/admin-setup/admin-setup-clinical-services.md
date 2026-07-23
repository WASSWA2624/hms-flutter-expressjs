# Refine Clinical Services desk tables — `/admin/setup?section=clinical-services`

Make Radiology, Lab, and Diagnoses catalog tables sort on every data column, wrap cell text cleanly, and respond without lag on nested tab switches.

## Context

- Nested strip in `FacilityCatalogConfigPanel`: Radiology / Lab / Diagnoses (global lists).
- Configure / Add / Edit / Delete unchanged. See `screens/admin-setup-clinical-services.md`. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. On Diagnoses, any create/enable primary still labeled “Add service(s)” must show **Add diagnosis** (l10n); other labels unchanged.
2. Every visible data column on all three tables must be sortable (exclude actions). Header click toggles direction with a clear sort indicator.
3. Cell text wraps inside the row without clipping, horizontal overflow, or broken actions across viewports.
4. Client sort on warmed data is immediate; no redundant fetches or full rebuilds on header click.
5. Nested tab switches show cached rows immediately when already loaded; first-load, empty, error/retry stay clear. Mutation success unchanged. Unauthorized mutate chrome stays hidden per existing gates.

## Constraints

- Reuse `AppListTable`, catalog loaders, dialogs, RBAC/ABAC, and theme tokens (light/dark).
- No new domains, routes, or refactors.

## Acceptance Criteria

- Diagnoses create/enable CTAs read **Add diagnosis** only.
- All three tables sort by any data column with visible direction; actions not sortable.
- Long values wrap; actions stay usable across viewports.
- Warmed sort and tab switch are not multi-second blank waits.
- Loading, empty, error/retry, success, and auth visibility correct.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/facility_catalog/clinical_catalog_admin_dialogs.dart`
- `frontend/lib/l10n/app_en.arb`
- `screens/admin-setup-clinical-services.md`
