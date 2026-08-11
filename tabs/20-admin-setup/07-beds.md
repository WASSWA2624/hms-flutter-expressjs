# Admin setup tab — Beds

## 1. Tab strip

- Label: `tenantFacilityWizardStepBeds`
- Icon: `Icons.bed_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `beds`
- Tab gate: facility\|tenant manage
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Hint: `tenantFacilityBedSearchHint`
- Add: `tenantFacilityAddBedAction`; block `tenantFacilityGateNeedWardsForBeds`
- Export default; Print off

## 3. Table

- Name = bed label; ward column; room/facility/tenant in details
- Status uses **bed operational status** labels (`tenantFacilityBedStatus*`)
- Details: `bed_details_dialog.dart`

## 4. Advanced filters / search fields

- `TenantFacilityBedsFilterKeys`: `tenant`, `facility`, `ward`, `room`, `bed_status` (+ soft-delete status group)

## 5. Primary / secondary / row actions

- CRUD

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Bed form (`showTenantFacilityBedFormDialog`) | Setup-owned |
| Details / similarity | Setup-owned |

## 7. Nested / follow-on

- Similarity

## 8. Forms (summary)

- Tenant/facility, label, ward (required), room (optional), bed status select

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Loading: `tenantFacilityBedsLoadingTitle/Body`
- Empty: `tenantFacilityNoBeds`
- Hard failure often plain `failureMessage` text (less polished than units)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | facility\|tenant manage |
| Mutations | `canEditStructure` |
| Export | ungated |
