# Lab Configure: prevent duplicate facility enables

## Objective

Deep-review and fix Admin Setup → Clinical Services → Lab **Configure** so already-offered tests/panels cannot be enabled again and are visibly marked.

## Context

Flow: Lab → **Configure** → scope picker → `LabEnableFacilityOfferingDialog` (`kind: all`; catalog → prices → preview → batch enable). Offerings match via id/code/name (`markLabCatalogItemsOfferedAtFacility`). Diagnosis shows offered rows as disabled **Configured**; Lab hides them—keep offered rows visible but non-selectable.

## Requirements

1. Resolve `isOfferedAtFacility` for the scoped facility for tests and panels.
2. Show offered rows with an explicit Configured/Already enabled mark; disable checkbox/select; exclude from select-all.
3. Deduplicate by type + stable identity (`apiId` else code/id) before render, selection, pricing, and enable.
4. Block duplicate active offerings in UI and `onEnable`/backend for the same catalog identity at that facility.
5. After in-session enable, mark rows offered immediately, clear them from selection, and keep them non-selectable.
6. Cover loading, empty (all configured), error, success, and Next-disabled-until-selection states; leave auth gates unchanged.

## Constraints

Reuse existing dialogs, match helpers, l10n, and design-system controls. No unrelated refactors. Follow `.cursor/mandatories.mdc` and `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

- Offered rows show Configured/Already enabled and cannot be selected or submitted again.
- Duplicate identities appear once; enable cannot create a second facility offering.
- In-session enables update the catalog immediately; unauthorized controls stay absent.
- Tests cover marking, select-all exclusion, dedupe, and post-enable lockout; manual check mobile/desktop light+dark.

## Relevant Files

- `screens/admin-setup/clinical-services.md`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_offering_match.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/test/shared/lab_catalog/lab_enable_offering_dialog_test.dart`
