# Admin setup tab — Clinical catalog

## 1. Tab strip

- Label: `tenantFacilitySetupTabClinicalCatalog`
- Icon: `Icons.medical_information_outlined`
- Count source: **none** (nested strip also without desk counts)
- Count tone: n/a
- Deep-link `section`: `clinical-services` (aliases `clinical-catalog`, `clinical`, `catalog`, `services`)
- Tab gate: facility\|tenant manage
- Nested tabs: Radiology / Lab / Diagnoses (`tenantFacilityCatalogTabRadiology|Lab|Diagnoses`) — **not** URL-synced
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Per-table search: `tenantFacilityCatalogSearchHint`
- Filters: `commonFiltersActionLabel`
- Settings keys: `admin_catalog_radiology|lab|diagnoses`
- **Export via `exportConfig`**; Print off
- Configure: `tenantFacilityCatalogConfigureAction`
- Add procedure/test/diagnosis when mutate policy allows (`radiologyCreateProcedureAction`, lab create, `clinicalCreateDiagnosisAction`)
- Panel `enabled: canManageFacility || canManageTenant`

## 3. Table / panel

- `FacilityCatalogConfigPanel` — three `AppListTable`s (radiology / lab / diagnosis)
- Columns include name/code/modality|category/price/actions by mutate rights
- Row select → edit when allowed

## 4. Advanced filters / search fields

- Radiology modality
- Lab type/category/result_kind/specimen/source
- Diagnosis category

## 5. Primary / secondary / row actions

- Configure offerings; create/edit/soft-delete/restore catalog items (standard items protected)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Radiology / lab / clinical catalog mutate & details | **reused** shared catalogs |
| Configure visibility helpers | **reused** shared facility catalog |

## 7. Nested / follow-on

- Nested configure + mutate dialogs; realtime sync for radiology/lab

## 8. Forms (summary)

- Forms live in shared catalog dialogs (modality, fees, specimens, etc.)

## 9. Print / labels / preview

- No preview-first Print; CSV export only

## 10. Loading / empty / error / success

- Per-tab loading/failure banner/empty
- Success often `labSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | facility\|tenant manage |
| Mutate radiology | `canMutateRadiologyCatalog` (∪ `radiology:write`\|admins) |
| Mutate lab | `canMutateLabCatalog` (`lab:write`\|admins) |
| Mutate clinical | `canMutateClinicalCatalog` (`clinical:write`\|admins) |
| Export | not ∩ `evidence:export` |
| Nested URL for radiology/lab/diagnoses | not synced |
