# Pharmacy Catalog · Room Tab: Export Filters, Similarity CRUD, Soft/Hard Delete, Room-Only Actions

**Objective:** Refine the Catalog and stock **Room** nested tab (`PharmacyCatalogTab.storageLayout`, labeled “Room”) so room Create/Edit enforce unique codes (auto-generate when omitted), run similarity review before save, soft-delete then restore/permanent-delete with cascade, open a room-details dialog after create, expose Export date/status filters, and keep row actions room-scoped only (no per-row Create shelf) — without changing Drugs, Formulary, Inventory, Shelves, dispensing, billing, or desk routing unless a requirement below says so.

## Context

Catalog and stock is already an inline desk section (`?section=catalog`) with nested tabs Drugs / Formulary / Inventory / **Room** / Shelves (`PharmacyCatalogPanel` → `_StorageLayoutCatalogTab`). The Room table is live today:

| Surface | Current behavior |
| --- | --- |
| Settings | Column visibility for Room name, Room code, Shelves, Status, Actions — keep |
| Export | `AppListTable` Export shows **columns only**; Room search sets `enableDateFilter: false` and has **no** `exportConfig` filters (status / created-at), so users cannot narrow the export set |
| Toolbar Create | Search trailing **Create** → `openPharmacyStorageRoomDialog` (create room) — keep as the room-create entry |
| Row actions | **Create** (opens shelf dialog) + **Edit** + **Delete** via `_catalogRowActions` with `fixedWidth: 280` — Create-shelf on the Room table is in scope to **remove**; shelf create stays on Shelves tab / room details |
| Create/Edit dialog | `_StorageRoomDialog` (`pharmacy_storage_panel.dart`): name required, code optional free text, active switch on edit; **no** uniqueness check, **no** auto code, **no** similarity review; on success pops back to the table |
| Delete | `confirmDeletePharmacyStorageRoom` → `deleteStorageRoom` → backend `txSoftDeleteStorageRoom` + soft-delete shelves; **no** restore / permanent-delete UI; soft-deleted rooms disappear from the default layout list (`is_active: true` unless `include_inactive`) |
| Backend | `pharmacy_storage_room` has `code` (nullable), `human_friendly_id`, `created_at`, `deleted_at`; create accepts optional `code` with **no** facility-scoped uniqueness or similarity endpoint yet |
| RBAC | Browse/write gated by `pharmacyCatalogBrowseRequirement` / `pharmacyCatalogWriteRequirement` |

Existing patterns to reuse (do not invent parallel frameworks):

- Similarity review UX: tenant-facility room/department/unit dialogs (`room_similarity.dart`, `*_similarity_dialog.dart`) and backend `*-similarity` libs (e.g. department) — adapt for **pharmacy storage rooms** (name + code), not facility clinical rooms.
- Soft → restore → permanent delete: department `restore` / `permanentDelete` routes and UI patterns.
- HFID / public ids: existing `human_friendly_id` + `toPublicIdentifier` on storage rooms; when `code` is omitted, generate a unique facility-scoped human-friendly **code** (or reuse HFID as the displayed code) before insert.
- Export filters: `AppListTableExportConfig` dateOf / rowFilter + search-bar date filter patterns used elsewhere when `enableDateFilter: true`.

Deep link scope remains `?section=catalog` with nested Room tab selected (`storageLayout`). If a nested-tab query param is already supported, keep it; otherwise do not invent a new desk section — optional `?catalogTab=room|storageLayout` is allowed only if it fits existing URL helpers without breaking current aliases.

## Requirements

1. **Room-table actions are room-only.** On `_StorageLayoutCatalogTab`, remove the per-row **Create** (add shelf) button. Row actions are **Edit** and **Delete** (or Restore / Delete permanently when soft-deleted — see R6). Shrink `fixedWidth` accordingly so the Actions column stays non-clipping. Shelf creation remains available from the **Shelves** nested tab (and from the new room-details surface in R5). Toolbar/search **Create** continues to mean **create room**.

2. **Create room: optional unique code + auto-generate.** In `_StorageRoomDialog` (create) and backend `createPharmacyStorageRoom`:
   - **Name** required.
   - **Code** optional in the form. If the user supplies a code, validate **facility-scoped uniqueness** among non-permanently-deleted rooms (case-insensitive trim); reject duplicates with a clear field error.
   - If code is empty, the backend **assigns** a unique human-friendly code (prefer existing HFID/public-id machinery or an equivalent short facility-unique code) before persist. Never create two rooms with the same code in the same facility.
   - Persist/refetch as today; audit log stays.

3. **Similarity review on create (and edit).** Before committing create/update, run a pharmacy-storage-room similarity check against other rooms in the facility (exclude the room being edited):
   - Detect **exact** name (and exact code when provided) conflicts → **block** create/update (hard stop); do not offer “create anyway” for exact duplicates.
   - Detect **near** matches (spelling / fuzzy name, and code similarity when applicable) with a percentage score (0–100).
   - Always surface a similarity review dialog after the check (including “0% / no close matches” and high scores), following the existing tenant-facility similarity dialog pattern (proposed values, match list, overall %).
   - For non-exact similar matches, user may **Continue / Create anyway** or cancel back to the form.
   - Wire a backend check endpoint (or extend create/update to return a similarity challenge) consistent with department/facility duplicate-review contracts; keep tenant/facility scope and RBAC write-gated.

4. **Edit room reuses the same uniqueness + similarity rules.** Edit dialog keeps name/code/active. Uniqueness and similarity peers **exclude the current room id**. Exact duplicate of another room’s name or code remains blocked.

5. **After successful create, open room details (do not only return to the table).** On create success, dismiss the create form and open a **room details** dialog/panel showing the new room (name, code, status, shelves count / shelf list summary, and affordances to add shelf / edit / soft-delete as write-allowed). From details, Add shelf may open the existing `_StorageShelfDialog`. Closing details returns to the Room table with data refreshed. Edit success may stay on details or return to the table; prefer opening/refreshing details when edit was launched from details.

6. **Soft delete → Restore / Delete permanently (cascade).** Replace the current one-shot delete UX with:
   - **Soft delete** (existing backend soft-delete of room + shelves): room leaves the active list (or appears inactive/deleted depending on filter); row actions become **Restore** and **Delete permanently** (write-gated).
   - **Restore**: clear soft-delete / reactivate room (and decide shelf restore policy consistently — prefer restoring shelves soft-deleted with the room when still intact).
   - **Delete permanently**: hard-delete the room and **cascade** dependent storage shelves (and any safe cascade rules for batch location FKs already defined in schema — never leave orphan shelves; follow referential integrity; if batches still reference the room, either block permanent delete with a clear message or null/reassign per existing pharmacy storage rules — document the chosen safe behavior and implement it).
   - Expose backend restore + permanent-delete endpoints mirroring department patterns; list/layout APIs must support including soft-deleted rooms when Filters request them (see R7).

7. **Export filters for Room.** Wire Room Export so the dialog includes useful filters in addition to column picks:
   - **Created date** From/To (`created_at` via `exportConfig.dateOf` / enabling date filter on the Room search where appropriate).
   - **Status** (Active / Inactive / Soft-deleted) and any other Room filters already on Advanced Filters once added.
   - Default export = current visible/filtered set with **no** date constraint (everything matching current search/filters); users can narrow by date/status before download.
   - Keep Export icon/label behavior from the shared table; do not change Drugs/Formulary/Inventory/Shelves export unless sharing a helper.

8. **Room list Filters + Settings completeness.** Keep Settings. Add Advanced Filters appropriate to rooms (at least status / include soft-deleted; created-at if not only on Export). Search continues to match name, code, and id. Prefer loading soft-deleted rows only when the filter asks for them so the default Room tab stays an active operational list.

9. **RBAC / ABAC.** Browse Room tab with `pharmacyCatalogBrowseRequirement`; Create / Edit / Soft-delete / Restore / Permanent-delete / Add-shelf-from-details with `pharmacyCatalogWriteRequirement`. Hide unauthorized write controls; never show disabled “no access” chrome. Backend remains authoritative.

10. **Preserve out-of-scope behavior.** Do not change Drugs, Formulary, Inventory, Shelves tab semantics (except that shelf create remains available there), order queues, stock alerts, dispensing, billing, or MAR.

## Constraints

- Prefer extending `pharmacy-storage.service.js` / repository / routes and `_StorageLayoutCatalogTab` / `_StorageRoomDialog` rather than a parallel catalog stack.
- Reuse similarity dialog patterns and soft/hard-delete patterns from tenant-facility / department; adapt copy and fields to pharmacy storage rooms (name + code).
- Theme tokens (light + dark); responsive Actions column without overflow after removing Create-shelf.
- Room **codes** stay unique per facility among non-purged rows; HFID remains the public id as today.
- No change to unrelated modules; migrations only as needed for unique indexes / permanent-delete safety.

## Acceptance Criteria

- (R1) Room table row actions are Edit + Delete (or Restore / Delete permanently); no Create-shelf on the Room row; Shelves tab (and room details) still create shelves.
- (R2) Create with blank code persists a system-generated unique facility code; supplied codes that collide are rejected.
- (R3) Create/Edit always run similarity review; exact name/code duplicates are blocked; near matches show % scores and allow continue-anyway only when not exact.
- (R4) Edit excludes self from uniqueness/similarity peers.
- (R5) Successful create opens room details; table refreshes; details can add shelves when write-allowed.
- (R6) Soft delete then Restore or permanent cascade delete works end-to-end; permanent delete does not leave orphan shelves.
- (R7) Room Export dialog exposes created-date range and status (and respects advanced filters); default is unfiltered-by-date export of the current set.
- (R8) Settings still work; Filters cover status / soft-deleted inclusion as specified.
- (R9) Read-only catalog users can view; only write-capable pharmacy catalog users mutate.
- (R10) Other catalog nested tabs and pharmacy order flows behave as before.

## Verification

- Frontend tests: `pharmacy_storage_panel_test.dart`, `pharmacy_storage_delete_test.dart`, catalog/workspace tests — cover room-only row actions, create→details, similarity block/continue, soft/restore/permanent UI gating, export filter presence.
- Backend Jest: `pharmacy-storage.service.test.js` — unique code generation, uniqueness conflicts, similarity check, soft/restore/permanent cascade.
- Manual: `?section=catalog` → Room — Create (blank & supplied code), similarity dialog, details after create, Edit, soft-delete → Restore / permanent delete, Export with date/status filters, RBAC with read vs write pharmacy users; light + dark; no Actions overflow.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (`_StorageLayoutCatalogTab`, row actions, search/export wiring)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart` (`_StorageRoomDialog`, delete confirm, shelf dialog reuse)
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` (create/update/delete/restore/permanent; layout reload; include soft-deleted)
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` / DTOs / repository
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`
- `frontend/lib/shared/components/app_list_table.dart` / `app_list_table_export.dart` (export filters)
- Similarity UI/domain patterns under `frontend/lib/features/tenant_facility/**` (reference only)
- `backend/src/modules/pharmacy-workspace/services/pharmacy-storage.service.js`
- `backend/src/modules/pharmacy-workspace/repositories/pharmacy-storage.repository.js`
- `backend/src/modules/pharmacy-workspace/schemas/**`, routes/controllers for storage rooms
- `backend/prisma/schema.prisma` (`pharmacy_storage_room` / shelf — unique code index if required)
- `frontend/test/features/pharmacy/presentation/pharmacy_storage_*_test.dart`, workspace/catalog tests
- `backend/src/tests/modules/pharmacy-workspace/services/pharmacy-storage.service.test.js`
