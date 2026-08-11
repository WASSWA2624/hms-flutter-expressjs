# Admin setup tab — Rooms

## 1. Tab strip

- Label: `tenantFacilityWizardStepRooms`
- Icon: `Icons.meeting_room_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `rooms`
- Tab gate: facility\|tenant manage
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Hint: `tenantFacilityRoomSearchHint`
- Add: `tenantFacilityAddRoomAction`; block `tenantFacilityGateNeedFacilityForRooms`
- Export default; Print off

## 3. Table

- Extra ward column; optional floor/facility/tenant
- Details: `room_details_dialog.dart`

## 4. Advanced filters / search fields

- `TenantFacilityRoomsFilterKeys`: `tenant`, `facility`, `ward`, `status`

## 5. Primary / secondary / row actions

- CRUD

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Room form (`showTenantFacilityRoomFormDialog`) | Setup-owned |
| Details / similarity | Setup-owned |

## 7. Nested / follow-on

- Similarity; ward optional (`tenantFacilityRoomOutpatientLabel` for none)

## 8. Forms (summary)

- Tenant/facility, name, ward (optional outpatient), floor
- **No active switch** (rooms lack `isActive` on entity)

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Loading: `tenantFacilityRoomsLoadingTitle/Body`
- Empty: `tenantFacilityNoRooms`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | facility\|tenant manage |
| Mutations | `canEditStructure` |
| Soft-delete status | rooms soft-delete only |
| Export | ungated |
