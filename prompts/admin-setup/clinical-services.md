# Lab Configure: harden batch enable wizard

Fix Clinical Services → Lab **Configure** so selection stays responsive, prices stay independent, and Review Selection shows unit prices before enable.

## Context

`LabEnableFacilityOfferingDialog` (catalog → prices → preview → enable) exists. Gaps: large-list select jank; no select/deselect-all; Next lag; duplicates; linked prices; preview missing Price.

## Requirements

1. Keep Configure scope rules and wizard steps; do not redesign the flow.
2. Keep catalog multi-select responsive on large lists. Add **Select all** / **Deselect all** for listed available rows (reuse `labSelectAllTestsAction` or equivalent; add Deselect-all l10n if missing).
3. Deduplicate catalog rows by stable identity (`apiId`, else type + code/id) before render, selection, and prices.
4. Bind each price/currency field to one selected item (stable keys + per-item controllers). Editing one must not change another.
5. Advance catalog → price → preview immediately; load only for network. Keep Next gating (≥1 selection; required positive unit prices).
6. Preview always shows Unit price per remaining item. **Enable selected** batch-upserts offerings for the scoped facility and refreshes Lab.

## Constraints

Reuse `AppListTable`, `AppCurrencyAmountField`, offering APIs, permissions, l10n, Radiology patterns. Follow `.cursor/mandatories.mdc`. No multi-facility batch.

## Acceptance Criteria

- Select/deselect-all targets listed available items; toggles stay snappy on large catalogs.
- No duplicate rows; each selected item has an independent price.
- Preview always shows Price; Enable persists offerings for the scoped facility.
- Tests cover select-all, price isolation, preview price, dedupe; check mobile/tablet/desktop light+dark.

## Relevant Files

- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/test/shared/lab_catalog/lab_enable_offering_dialog_test.dart`
- `screens/admin-setup/clinical-services.md`
