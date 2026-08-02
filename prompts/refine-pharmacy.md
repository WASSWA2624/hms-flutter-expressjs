# Pharmacy Catalog · Rooms Tab: Table Layout, Similarity Review UX, Use Existing, Tab Rename

**Objective:** Polish the Catalog and stock **Rooms** nested tab (today labeled “Room”; `PharmacyCatalogTab.storageLayout`) so the table is left-aligned with sensible column widths (Edit + Delete fully visible), the storage-room similarity review dialog clearly compares proposed vs existing fields with color-coded scores and a **Use existing** path, and the nested tab label is **Rooms** — without changing Drugs, Formulary, Inventory, Shelves semantics, dispensing, billing, or desk routing unless a requirement below says so.

## Context

Catalog and stock (`?section=catalog`) already ships Room CRUD from the prior refine pass. Live behavior today:

| Surface | Current behavior |
| --- | --- |
| Nested tab label | `pharmacyCatalogTabStorage` → **“Room”** (singular) |
| Room table (`_StorageLayoutCatalogTab`) | Columns: Room name, Room code, Shelves, Status, Created at, Actions; filters (status / include deleted); export with date + status; create → similarity → details |
| Column layout | Shelves (count) and Status use default / generous widths; Actions `fixedWidth: 220` with `_catalogRowActions` + `FittedBox(scaleDown)` — **Delete often clips or shrinks** so screenshots show Edit only |
| Cell alignment | Numeric/status cells and dense table chrome do not consistently **left-align**; name/code feel centered in the middle of wide columns |
| Search hint | Uses generic `pharmacySearchHint` (“Search patient, order, encounter…”) — wrong for Rooms |
| Create/Edit dialog | Name required, code optional; active switch on edit — keep |
| Similarity dialog | Plain `AppDialog` + `ListTile` list (`name`, `code · score%`); exact block vs “Create anyway” works, but **no proposed-vs-existing field comparison**, weak Exact/Near visual language, **no Use existing** |
| Uniqueness | App-level facility-scoped exact name/code block on create/update; **no DB unique index** — legacy duplicate codes (e.g. two Active rooms both `RM001`) can still appear in the table |
| Soft/hard delete | Soft delete → Restore / Delete permanently remain; do not regress |
| Reference UX | Tenant-facility `room_similarity_dialog.dart` / `facility_similarity_dialog.dart` — banner variants, proposed card, match cards with Exact/Near badges, field comparison grid, **Use existing** |

Screenshots confirm: Actions often show Edit only; duplicate `RM001` rows still list; Duplicate Room / Similar Rooms Found dialogs are list-only; Create Room form is fine functionally.

## Requirements

1. **Rename nested tab to Rooms.** Update the Catalog nested-tab label from “Room” to **“Rooms”** (`pharmacyCatalogTabStorage` / related l10n). Keep enum/`storageLayout` ids and URL aliases stable unless an existing helper already maps display copy only.

2. **Fix Room table column spacing so Actions are fully visible.** On `_StorageLayoutCatalogTab` (and apply the same layout discipline to the **Shelves** nested table if its Actions are clipped for the same reason — Shelves count/status columns eating width):
   - Tighten **Shelves** (count) and **Status** preferred/fixed widths so they do not dominate horizontal space.
   - Size **Actions** so **Edit** and **Delete** (or Restore / Delete permanently) render fully without relying on aggressive `FittedBox` scale-down that hides Delete.
   - Prefer left-aligned text for name, code, shelves count, status, and created-at cells (and Actions content) unless `AppListTable` already documents a stronger shared default — if a shared table default for left alignment is the cleanest fix, apply it carefully without breaking intentional numeric right-align elsewhere in pharmacy tables; otherwise set per-column alignment on Rooms (and Shelves if touched).
   - Do not remove columns; keep Settings / column visibility.

3. **Rooms-specific search hint.** Replace the Room-tab search placeholder with copy appropriate to rooms (name, code, id) — new l10n key preferred; do not change the shared queue hint used by order tabs.

4. **Similarity review: proposed vs existing, color-coded, comprehensive fields.** Replace the thin ListTile similarity dialog in `_StorageRoomDialog` with a pharmacy-storage-room adaptation of the tenant-facility similarity pattern:
   - Always show review after check (including 0% / no close matches), as today.
   - Show **proposed** values (name, code — and any other fields already in the similarity payload/result) clearly labeled.
   - For each match, show **existing** room name/code (and status if useful) beside proposed, with per-field comparison and overall % score.
   - Color-code Exact vs Near (and blocked exact duplicates) using theme tokens / existing `AppFormInformationVariant` banner patterns — not one-off hard-coded colors.
   - Exact name or exact code conflict remains a **hard stop** (Cancel only / no Create anyway), consistent with backend.
   - Near matches keep **Create anyway / Continue**; cancel returns to the form.
   - Ensure the check still covers **all parameters the backend already scores** (name + code today); if the API already returns field-level scores/flags, surface them — do not invent new backend scoring dimensions unless needed to display existing fields.

5. **Use existing room.** On similarity review when matches are listed (exact or near), add a clear **Use existing** (or per-match select) action:
   - Choosing an existing room **dismisses create**, does **not** create a duplicate, and opens that room’s **details** dialog (same surface as post-create details) or focuses/selects that row — prefer details for parity with create-success.
   - Exact-duplicate dialogs should emphasize Use existing / Cancel over Create anyway (Create anyway stays unavailable when exact).
   - Wire result handling in `_StorageRoomDialog` / catalog Create trailing action accordingly; edit flow: Use existing may simply cancel edit or open the other room’s details without applying the draft — document and implement the safer of the two (prefer cancel draft + open details of the selected peer).

6. **Preserve Room CRUD already shipped.** Do not regress: auto-code when blank, soft → restore / permanent cascade, create → details, export date/status filters, include-deleted filters, RBAC (`pharmacyCatalogBrowseRequirement` / `pharmacyCatalogWriteRequirement`). Legacy duplicate codes in the DB may remain visible until cleaned; new creates/updates continue to block exact code/name collisions. Optional unique index / data cleanup is **out of scope** unless required to finish layout or Use existing.

7. **Out of scope.** Drugs, Formulary, Inventory behavior; Shelves CRUD semantics beyond Actions/column layout polish if clipped; order queues; billing; facility clinical rooms (only reuse their similarity **UI pattern**).

## Constraints

- Prefer extending `_StorageLayoutCatalogTab`, `_catalogRowActions`, `_StorageRoomDialog`, and a dedicated pharmacy storage-room similarity dialog widget over a parallel catalog stack.
- Reuse tenant-facility similarity dialog structure (`RoomSimilarityDialogResult`-style cancel / useExisting / proceed) adapted to `PharmacyStorageRoom` — do not import facility room entities into pharmacy domain.
- Theme tokens (light + dark); responsive Actions without overflow; left alignment as specified.
- No unrelated module changes; migrations only if strictly needed (prefer UI/layout + dialog polish only).

## Acceptance Criteria

- (R1) Nested tab label reads **Rooms**.
- (R2) Room table Actions show full Edit + Delete (or Restore / permanent) without clipping; Shelves/Status columns no longer starve Actions; primary text cells are left-aligned as specified.
- (R3) Room search hint refers to room name/code (not patient/order queue copy).
- (R4) Similarity dialog shows proposed vs existing fields, color-coded Exact/Near/%, and covers name + code (and any returned field scores).
- (R5) Exact conflicts block Create anyway; near matches allow Create anyway; **Use existing** opens the selected room’s details (or equivalent) without creating a duplicate.
- (R6) Soft/hard delete, auto-code, export/filters, create→details, and RBAC still work.
- (R7) Other catalog nested tabs and pharmacy order flows behave as before (aside from intentional Shelves column-width fix if applied).

## Verification

- Frontend: catalog/storage widget tests — Actions visibility (or golden/layout smoke), similarity Use existing / exact block / create anyway, tab label “Rooms”, rooms search hint.
- Manual: `?section=catalog` → Rooms — confirm left-aligned columns, Edit+Delete visible on Active rows, Create with near-match → Use existing → details, exact duplicate → no Create anyway, light + dark.
- Backend: no API change required unless field-level scores must be exposed for the comparison grid; if so, extend similarity response only and cover with existing Jest suite.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (`_StorageLayoutCatalogTab`, `_catalogRowActions`, Shelves tab if layout-touched)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_tabs.dart` / `app_en.arb` (`pharmacyCatalogTabStorage` → “Rooms”; rooms search hint)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart` (`_StorageRoomDialog`, details entry after Use existing)
- New or colocated: pharmacy storage-room similarity dialog (pattern from `frontend/lib/features/tenant_facility/presentation/widgets/room_similarity_dialog.dart`, `facility_similarity_dialog.dart`)
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` (similarity result / field flags if needed for UI)
- `frontend/lib/shared/components/app_list_table.dart` (only if shared left-align / width defaults are the right fix)
- `backend/src/lib/pharmacy/pharmacy-storage-room-similarity.js` / `pharmacy-storage.service.js` (only if response shape must expose per-field scores for the grid)
- Tests: `frontend/test/features/pharmacy/presentation/pharmacy_storage_*_test.dart`, catalog tests as needed
