# Clinical Services Configure → Enable Offerings

Make Clinical Services **Configure** open each nested tab’s facility enable dialog with the titles below.

## Context

- Target: `/admin/setup?section=clinical-services` (`FacilityCatalogConfigPanel`).
- Nested tabs Radiology, Lab, Diagnoses already expose **Configure**. Keep the scope-picker → enable-dialog chain; correct titles and Lab coverage.

## Requirements

1. Keep **Configure** on Radiology, Lab, and Diagnoses when the panel is enabled and configuration is authorized.
2. On Configure, open the scope picker when needed; after a valid scope, open the matching enable dialog without switching the desk to facility-only mode.
3. Set enable-dialog titles (l10n): Radiology → **Enable radiology procedures**; Lab → **Enable lab tests and panels**; Diagnoses → **Enable clinical diagnoses**.
4. From Clinical Services Lab Configure, allow enabling both tests and panels (not tests-only).
5. Preserve existing enable flows and their loading, empty, error, success, and validation feedback.
6. Unauthorized Configure/enable UI must not render; after successful enable, refresh warmed catalog/offering state.

## Constraints

- Reuse existing enable dialogs, scope picker, RBAC/ABAC, theme tokens, and design-system components; no unrelated refactors.
- Stay responsive on mobile, tablet, and desktop in light and dark themes.

## Acceptance Criteria

- Each tab’s Configure opens the correctly titled enable dialog via the existing scope chain.
- Lab Configure can enable tests and panels.
- Unauthorized users never see Configure/enable chrome; authorized users retain access.
- Tests or manual checks cover the three Configure paths, titles, Lab test+panel enable, and post-enable refresh.

## Relevant Files

- `facility_catalog_config_panel.dart`, radiology/lab/diagnosis enable dialogs, `app_en.arb`, `screens/admin-setup-clinical-services.md`
