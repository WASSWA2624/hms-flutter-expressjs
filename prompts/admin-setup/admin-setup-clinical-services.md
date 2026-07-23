# Refine Radiology Configure enable wizard

Rewrite Clinical Services → Radiology → **Configure** for batch-select, batch-price, preview, then one enable—always-visible disabled Next; hide already-offered rows.

## Context

`/admin/setup?section=clinical-services`. Keep scope picker. Today `RadiologyEnableFacilityOfferingDialog` is catalog → preview → per-item price; Next hidden until selection; offered rows shown; footer Back, Close, Next.

## Requirements

1. Keep scope Next gated on tenant + facility; cancel/close abort without enable.
2. Catalog footer **Back**, **Next**, **Close** (Close rightmost). Always show Next; disable with tooltip/reason until ≥1 available procedure selected.
3. Catalog lists only procedures not already offered at the scoped facility.
4. Next opens **batch price**: stacked selections with required unit price each (existing currency field). No per-item price screens.
5. Then **preview** name/code/modality/price; allow remove; block with reason if empty or invalid prices.
6. One submit enables all remaining via `onEnable`; show failure; sync/close on success per callers.
7. Cover loading, empty, filter empty, validation, error, success; catalog Back → scope when `showBackAction`.

## Constraints

Reuse dialog, scope picker, design-system, validation, auth. No Lab/Diagnoses Configure changes.

## Acceptance Criteria

- Catalog Next always visible; disabled explains select ≥1; enabled only with selection.
- Footer Back → Next → Close; offered rows never in catalog.
- Flow catalog → batch prices → preview → batch enable; preview can remove; empty blocked.
- Unauthorized UI absent; light/dark and narrow viewports usable.

## Relevant Files

- `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/test/shared/radiology_catalog/radiology_enable_offering_dialog_test.dart`

## Verification

Update widget tests for flow, footer, disabled Next, and hidden offered rows.
