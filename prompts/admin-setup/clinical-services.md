# Diagnoses Configure: permissions + multi-enable

## Objective

Gate Diagnoses **Configure** by effective access, and keep **Enable clinical diagnoses** open so users can enable multiple offerings without returning to the desk after each add.

## Context

- Route: `/admin/setup?section=clinical-services` → Diagnoses in `FacilityCatalogConfigPanel`.
- Inventory: `screens/admin-setup/clinical-services.md` (`DiagnosisEnableFacilityOfferingDialog`).
- Configure today uses `widget.enabled` only. Backend offerings upsert requires `clinical:write`.
- Successful enable calls `Navigator.pop(true)` and returns to the desk. Lab Configure stays open and marks **Configured**.

## Requirements

1. Add a policy helper (mirror `canMutateLabCatalog`) aligned with backend `clinical:write` / admin scopes for diagnosis offering enable.
2. Show Diagnoses **Configure** only when the panel is enabled and that helper allows; omit unauthorized control (no disabled stub).
3. Keep enable flow unreachable without the same grant; backend remains authoritative.
4. On successful enable in `DiagnosisEnableFacilityOfferingDialog`: mark **Configured**, clear failure, stay open—do not pop.
5. **Close** pops `true` if any enable succeeded this session, else `null`/`false`; parent toast/refresh only after dismiss.
6. Cover loading, error banner, Configured row, and unauthorized Configure absence.

## Constraints

- Reuse Lab stay-open / Configured pattern, existing dialogs, gates, and l10n.
- Follow `.cursor/mandatories.mdc`, `prompts/.cursor/prompt.mdc`, permission rules.
- No unrelated Radiology/Lab Configure refactors.

## Acceptance Criteria

- Unauthorized: Configure absent. Authorized: Configure opens enable flow.
- Enabling one diagnosis leaves the dialog open for more; Close returns once.
- Tests prove unauthorized Configure absent and multi-enable without dismiss.

## Relevant Files

- `facility_catalog_config_panel.dart`, `clinical_catalog_admin_dialogs.dart`
- `access_policy.dart`, `clinical-catalog.routes.js`
- `screens/admin-setup/clinical-services.md`
- Widget/policy tests under `frontend/test/`
