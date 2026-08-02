# Pharmacy Catalog Shelves: Details, Unified Create, and Room-Scoped Similarity

**Objective:** Keep the Catalog → Shelves table as-is for listing, then add a polished shelf **details** dialog on row select, replace the Create **Next** room-picker wizard with a **single** Add shelf dialog (room + fields together), require shelf label, allow optional blank shelf code with backend auto-generation, and run create/edit **similarity review scoped to shelves in the selected room** using the shared `AppSimilarity` components and the existing Rooms similarity flow as the pattern.

## Context

Screenshots and code show Catalog and stock → **Shelves** (`?section=catalog`, `_ShelvesCatalogTab` in `pharmacy_catalog_panel.dart`):

| Surface | Current behavior |
| --- | --- |
| Shelves table | Looks correct: Shelf code, Shelf label, Storage room, Status, Actions (Edit / Delete); toolbar **+ Create**; room column visible |
| Create | Two-step: dialog picks **Storage room** then **Next** → separate `_StorageShelfDialog` with code (required) + label (optional) + **Create shelf** |
| Row click | No details dialog — only Edit / Delete in the Actions column |
| Edit | Opens `_StorageShelfDialog` for that shelf’s room; no similarity |
| Delete | Confirm + soft delete via `confirmDeletePharmacyStorageShelf` |
| Similarity | **None** for shelves; Rooms already use `checkStorageRoomSimilarity` + `showAppSimilarityReviewDialog` / pharmacy adapter |
| Room details path | Room details already has **Add shelf** in the shelves body (pre-scoped room) — keep that entry working |

Raw intent: table display is fine; clicking a shelf opens a well-designed **details** dialog with Edit/Delete in the footer; Create is one dialog (search/select room + shelf form, no Next); code may be blank → system generates human-friendly id; **label is required**; similarity compares against shelves **in that room only** (same code/label allowed in a different room); reuse shared similarity + existing pharmacy storage flows.

## Requirements

1. **Preserve the Shelves table chrome.** Do not redesign columns, search, filters, Settings, Export, or generic Action labels (Create / Edit / Delete). Keep `pharmacyCatalogWriteRequirement` gating. Primary toolbar Create remains the entry for Add shelf from the tab.

2. **Open shelf details on row select.** On `onRowSelected` (and mobile item tap if applicable), open a polished **shelf details** dialog (mirror the improved room details pattern): summary header (code, label, status, parent room), info tiles, footer **Close**, **Edit**, **Delete** (write-gated; hide mutate actions when not allowed / soft-deleted if applicable). Edit opens the shelf form; Delete reuses `confirmDeletePharmacyStorageShelf`. After successful edit/delete, refresh storage layout state so the table and open details stay in sync.

3. **Single Add shelf dialog (no Next).** Replace `_promptAddShelf`’s room-only + Next wizard with one `AppDialog` that includes:
   - Searchable/select **Storage room** (required for create from the Shelves tab; when opened from room details / a known room, room is fixed/read-only).
   - **Shelf code** and **Shelf label** fields on the **same** dialog.
   - Footer **Cancel** + primary **Add shelf** (not Next). If no room is selected, still show the field shell; block submit with validation until room + required fields are valid.

4. **Field rules.** **Shelf label is required.** **Shelf code** may be left blank on create: backend assigns the human-friendly / display id (same contract style as storage rooms). On edit, preserve existing code unless the user changes it; keep Active switch on edit. Align frontend validators with these rules (do not require a non-empty code when auto-generate is allowed).

5. **Room-scoped similarity on create and edit.** Before persist, run a similarity check against **only shelves in the selected/parent room** (exclude self on edit). Exact code or label conflict in that room blocks proceed (Cancel / Use this shelf); near matches allow **Save anyway** / **Add anyway** with `confirm_similar`. Reuse `showAppSimilarityReviewDialog` via a thin pharmacy shelf adapter (like `pharmacy_storage_room_similarity_dialog.dart`), including editable proposed + **Check again** when the create/edit loop supports retry. Do **not** treat shelves in other rooms as conflicts.

6. **Backend similarity + auto-code.** Add shelf similarity-check (and wire create/update to enforce it) under pharmacy storage APIs, scoped by `storage_room_id`, modeled on `storage/rooms/similarity-check` and room create/update `confirm_similar`. Support blank code → generate friendly id. Return field comparisons suitable for the shared similarity UI.

7. **Reuse and sync.** Prefer existing `openPharmacyStorageShelfDialog`, controller create/update/delete shelf methods, and storage layout reload. Keep Drugs / Formulary / Inventory / Rooms semantics unchanged except shared helpers needed for shelves.

## Constraints

- Shared similarity stays domain-agnostic; pharmacy maps shelf models at the call site.
- Similarity peers = shelves in the **current room only**.
- No disabled “no access” chrome; unauthorized shelf write controls must not render.
- Light + dark; mobile/tablet/desktop without clipping the details/create dialogs.
- No unrelated catalog refactors or DB migrations beyond what shelf similarity / auto-code require.

## Acceptance Criteria

- (R1) Shelves table columns, Create/Edit/Delete, and room display remain intact.
- (R2) Selecting a shelf opens details with room/code/label/status and footer Edit/Delete/Close; Edit/Delete work and refresh the list.
- (R3) Toolbar Create opens one dialog with room selector + code + label and **Add shelf** (no Next step).
- (R4) Blank code on create succeeds with a generated friendly code; empty label fails validation.
- (R5) Duplicate/near shelf code or label **in the same room** shows shared similarity review; exact blocks Save anyway; near allows confirm; other rooms do not conflict.
- (R6) Edit path runs the same room-scoped similarity rules; Use this opens/uses the existing shelf without creating a duplicate.
- (R7) Add shelf from room details still works with room pre-selected and similarity scoped to that room.
- (R8) Unauthorized users do not see Create/Edit/Delete/Add shelf; authorized flows still work.

## Verification

- Widget/source tests: single-dialog create (no Next); details on row select; label required / code optional; similarity adapter maps cancel / proceed / useExisting / retry.
- Backend tests: room-scoped similarity; blank code generation; `confirm_similar` on create/update; exclude self on edit.
- Manual: `?section=catalog` → Shelves — Create (pick room, blank code, required label, similar/exact); row → details → Edit/Delete; Add shelf from Room details; light + dark; mobile width.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (`_ShelvesCatalogTab`, `_promptAddShelf`)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart` (`_StorageShelfDialog`, room details Add shelf, delete confirms)
- Shared similarity: `frontend/lib/shared/components/app_similarity.dart`; rooms adapter `pharmacy_storage_room_similarity_dialog.dart`
- Backend: `backend/src/modules/pharmacy-workspace/**`, `@lib/pharmacy/pharmacy-storage-room-similarity` (pattern for shelf similarity)
- Tests: pharmacy shelf / storage tests; new shared or shelf similarity widget tests as needed
