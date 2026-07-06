# Fix: Request Radiology dialog — label + Choose Imaging Study performance

## Goal

Make the **Request radiology** flow fast and responsive on web. Clinicians must be able to open **Choose imaging study**, search/filter studies, and confirm selections without the browser freezing.

## Current state (keep)

The following already work—do not regress:

- **Request radiology** dialog (`ClinicalRadiologyOrderActionDialog`): patient context strip, **Add study**, **Review billing**, selected-studies table, and **Request radiology** submit.
- **Choose imaging study** dialog (`ClinicalRadiologyRequestCatalogDialog`): modality / laterality / priority / body region filters, clinical note, search, table with checkboxes, **Confirm selected studies**.
- Entry points: patient registry quick actions, OPD flow, clinical / nursing / ICU / IPD workspaces, radiology workspace.

## Problems (from QA)

1. **Label:** Patient context shows **Name:** — should read **Patient name:** (screenshot).
2. **Severe latency / freeze:** Clicking **Add study** takes a long time; the page can become unresponsive (`Page Unresponsive` in Chrome). After the catalog dialog opens, interaction feels frozen (no visible response to clicks, typing, or scrolling).
3. **Likely root cause:** The catalog is loaded and rendered client-side from the **full tenant radiology test list** (~6,500 items via `clinical_repository_impl.dart` → `HmsApiResource.radiologyTests` with `include_standard_catalog: true`), not the **facility offerings** for the patient's facility. The catalog dialog then filters, sorts, and builds an `AppListTable` over the entire list on every build.

## Expected behavior

- Show only imaging studies **offered by the patient's facility** (same rule as lab ordering).
- Open **Choose imaging study** within ~1 s on web with a normal facility catalog size.
- Dialog remains interactive while loading (loading indicator / skeleton); search and filters debounce server requests instead of scanning thousands of rows synchronously on the UI thread.
- Do **not** load the global radiology catalog up front for this flow.

## Reference implementation

Mirror the **lab order** pattern:

| Concern | Lab (working) | Radiology (fix) |
|--------|---------------|-----------------|
| Catalog load | Server search via `onSearchLabTests` | Add `onSearchRadiologyTests` (or equivalent) |
| Facility scope | `searchClinicalTerms(…, termType: 'LAB_TEST', facilityId: …)` with `offeredOnly` | `termType: 'RADIOLOGY_TEST'`, same `facilityId` |
| Catalog dialog | `ClinicalLabRequestCatalogDialog` — async search | `ClinicalRadiologyRequestCatalogDialog` — async search |
| Parent dialog | `ClinicalLabOrderActionDialog` passes search callback | `ClinicalRadiologyOrderActionDialog` passes search callback |
| Patient quick action | `openPatientLabOrderDialog` wires `facilityId` from patient/session | `openPatientRadiologyOrderDialog` must wire the same |

**Primary files:**

- `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_request_catalog_dialog.dart`
- `frontend/lib/shared/patient_actions/patient_clinical_quick_actions.dart` (`openPatientRadiologyOrderDialog`)
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart` (`_openRadiologyOrderDialog`)
- `frontend/lib/features/clinical/data/repositories/clinical_repository_impl.dart` (stop bulk-loading radiology for request flow)
- `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` and other workspace entry points that open the radiology dialog
- Backend (if needed): `clinical-catalog` search with `offered_only` + `facility_id`; `facility-radiology-catalog` (`/search`, `/tests`)

**Localization:**

- `frontend/lib/l10n/app_en.arb` — change `clinicalRequestPatientNameLabel` from `Name` to `Patient name`.

## Implementation rules

- **Reuse** existing clinical catalog search (`searchClinicalTerms` / `searchClinicalCatalog` with `termType: 'RADIOLOGY_TEST'`, `offeredOnly: true`, `facilityId`). Do not invent a parallel API unless the existing search cannot return required fields (modality, body region, price).
- **Pass `facilityId`** from patient context (`patient.facilityId` or session facility) through every entry point that opens the radiology order dialog.
- **Paginate or limit** server results; default page size should match lab (~80). Load more on search/filter, not on dialog open.
- **Defer heavy work** off the build method: memoize filter option lists, debounce search, show loading state while fetching.
- **Remove or narrow** `_largeRadiologyCatalogPageSize` radiology preload from `loadReferenceData()` if it exists only to feed this dialog.
- **Scope:** request-radiology ordering UX only; radiology workspace configuration (`facility_catalog_config_panel`) is out of scope unless required for search wiring.
- **Tests:** extend `frontend/test/shared/clinical_actions/clinical_radiology_order_action_dialog_test.dart` to cover async catalog search and the updated label.

## Acceptance criteria

- [ ] Patient context label reads **Patient name:** (not **Name:**).
- [ ] **Add study** opens **Choose imaging study** quickly; no browser “Page Unresponsive” dialog under normal dev data.
- [ ] Catalog lists **facility-offered studies only** for the patient's facility—not the full tenant/standard catalog.
- [ ] Search, modality filter, and checkboxes respond immediately; loading state shown while fetching.
- [ ] **Confirm selected studies** returns selections to the parent dialog unchanged.
- [ ] Lab-order search/facility-scoping pattern is followed; no duplicate catalog-fetch logic.
- [ ] All radiology order entry points (patients page, OPD, clinical, nursing, ICU, IPD, radiology workspace) pass `facilityId` and use the async catalog.
- [ ] Existing widget tests pass; new test covers search callback wiring.
