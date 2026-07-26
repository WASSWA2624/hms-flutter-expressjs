# Lab Configure: role-aware scope and batch enable

Make Clinical Services → Lab **Configure** resolve scope by admin role, multi-select tests/panels, set default unit prices, then batch-enable facility offerings.

## Context

Lab Configure opens a role-aware scope picker then `LabEnableFacilityOfferingDialog` (one item via `_LabEnableOfferingPriceDialog`). Mirror Radiology’s catalog → batch prices → preview → batch enable. Offering prices stay facility defaults; order-time override remains allowed.

## Requirements

1. Keep Configure scope rules: elevated selects tenant + facility; tenant admin (no facility context) selects facility with tenant locked; facility-scoped actors skip the picker and use session scope.
2. Replace Lab per-row enable with multi-select wizard: catalog (tests + panels) → batch prices → preview → one batch enable, matching `RadiologyEnableFacilityOfferingDialog` (Back to scope when picker ran).
3. List only items not yet offered; Next needs ≥1 selection; prices required before preview; preview can deselect before save.
4. On success upsert offerings, refresh Lab table, show saved snackbar; keep unauthorized Configure/mutate controls absent.
5. Cover loading, empty, validation, save failure, and success with localized copy.

## Constraints

Reuse scope picker, offering upsert APIs, permissions, l10n, and design-system components. No multi-facility batch. Follow `.cursor/mandatories.mdc`.

## Acceptance Criteria

- Role matrix matches requirement 1.
- Lab Configure matches Radiology select → price → preview → enable for mixed tests/panels.
- Unauthorized users never see Configure/mutate; authorized users complete batch enable.
- Tests cover scope visibility and wizard gating; manual check mobile/tablet/desktop light+dark.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/shared/facility_catalog/clinical_catalog_admin_dialogs.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart`
- `screens/admin-setup/clinical-services.md`
