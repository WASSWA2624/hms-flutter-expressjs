# Pharmacy Room Details Dialog: Flatten Summary, Inline Meta, Shelves Table

**Objective:** Keep the Catalog → Rooms **room details** dialog (`openPharmacyStorageRoomDetailsDialog` / `_StorageRoomDetailsDialog`) as the single details surface, but restyle it: title **Room Details** (not the room name), remove the hero summary card, show room fields as wrapping icon + label + colon + value rows inside the **Storage room** section, move **Add shelf** into the Shelves section header (left of the chevron), and replace the shelf card list with a compact `AppListTable` (search / filters / settings) showing shelf id, name, status, and borderless Edit/Delete actions. Leave the dialog footer (Close / Delete / Edit room) as-is.

## Context

Screenshots (`pharmacy?section=catalog` → room row → details) and code show `_StorageRoomDetailsDialog` in `pharmacy_storage_panel.dart`:

| Surface | Current behavior |
| --- | --- |
| Dialog title | Room **name** (e.g. `ROOM 1`) + warehouse icon |
| Hero / summary card | Large icon + room name + Active badge + code + display id (`RM001`, `PSR-…`) |
| Storage room section | `AppCollapsibleSection` + **`AppInfoTileGrid`** of bordered cards (Room code, Status, Shelves count, Details/id, Created at) |
| Shelves section | Title + count; **Add shelf** is a secondary button **inside** the body (top-right of content, not in the header); shelves rendered as `_StorageRoomShelfRow` cards (code, label, status badge, Edit/Delete) |
| Footer | Close (tertiary), Delete/Restore (write-gated), Edit room (primary) — **keep** |
| Write gating | `AppAccessActionGate` + soft-deleted room hides mutate shelf/room edit |

Raw intent: data is correct, chrome is wrong — rename title; drop hero and fold identity into Storage room; replace info **cards** with inline icon/label/value rows that wrap; put Add shelf on the Shelves **header** just left of the chevron; shelves become a search+settings **table**; footer stays.

## Requirements

1. **Dialog title = “Room Details”.** Do not use the room name as `AppDialog.title`. Keep a suitable warehouse/storage icon. Room name still appears as a field (or primary value) inside the Storage room section, not as the window title.

2. **Remove the hero summary card.** Delete the top decorated summary block (large icon + name + status chip + code + display id). Do not replace it with another hero; identity moves into the Storage room section content.

3. **Storage room section: inline meta rows, not cards.** Keep the collapsible **Storage room** section. Replace `AppInfoTileGrid` bordered tiles with a wrapping list of rows in the form:
   - `[icon] Parameter name: value` on one line (same row),
   - wrap to the next row when horizontal space runs out (`Wrap` / responsive flow).
   - Include at least: room name, room code (copyable when present), status, shelves count, details/display id (copyable when present), created at when known — same data as today, flatter presentation. Prefer existing shared helpers if an inline icon+label+value pattern already exists; otherwise a small local/private row widget is fine. Preserve copy-to-clipboard for code and display id.

4. **Shelves section header: Add shelf beside the chevron.** Keep the Shelves collapsible title + count. Move **Add shelf** from the section body into `AppCollapsibleSection.headerActions` so it sits **immediately left of the expand/collapse chevron** (headerActions already render before the chevron). Keep write-gate + hide when soft-deleted. Do not leave a duplicate Add shelf in the body.

5. **Shelves body = `AppListTable`.** Replace `_StorageRoomShelfRow` cards with an `AppListTable` scoped to this room’s shelves:
   - Toolbar: search bar, filter control, settings (column visibility) — match shared table chrome used elsewhere (e.g. Catalog → Shelves). Export optional; default table export is fine unless it feels noisy in a dialog — prefer enabling consistent chrome over inventing a one-off toolbar.
   - Columns (order): **Shelf ID/code**, **Shelf name/label**, any other useful in-room fields already on the entity (skip parent **room** column — room is fixed), **Status**, **Actions**.
   - Actions: Edit and Delete as **simple icon + label** controls — no border, no filled background (tertiary / plain chrome). **Delete** stays destructive (red). Raw note said Edit icon red; treat Delete as the red/destructive action and Edit as standard primary/on-surface so Edit/Delete remain distinguishable (matches current row affordance and Catalog shelves).
   - Wire Edit → `openPharmacyStorageShelfDialog`, Delete → `confirmDeletePharmacyStorageShelf`; refresh from workspace state as today.
   - Empty state: keep a clear empty message when the room has no shelves.
   - Bound height inside the dialog so the table scrolls without blowing past `maxWidth` / dialog layout; mobile list mode via existing `AppListTable` adaptive behavior is OK.

6. **Preserve footer and room mutations.** Footer Close / Delete (or Restore) / Edit room stay as today, including access gates, soft-delete restore path, and re-opening details after “use existing” from room edit similarity.

7. **No unrelated catalog work.** Do not redesign the Rooms/Shelves worklists, shelf create similarity, or room create/edit forms except where details dialog wiring already calls them.

## Constraints

- Scope: `_StorageRoomDetailsDialog` (+ small private helpers / l10n for “Room Details” if missing). Prefer `pharmacy_storage_panel.dart`; avoid drive-by refactors of `AppInfoTileGrid` or `AppListTable`.
- Reuse `AppCollapsibleSection.headerActions` for Add shelf placement.
- Unauthorized users must not see Add shelf / Edit / Delete; soft-deleted rooms keep current mutate restrictions.
- Light + dark; dialog usable on mobile width without clipped header actions or table chrome.
- Preserve live refresh when `pharmacyWorkspaceControllerProvider` updates the room/shelves.

## Acceptance Criteria

- (R1) Dialog title reads **Room Details** (or localized equivalent), not the room name.
- (R2) Hero summary card is gone; name/code/status/id appear only via Storage room inline rows (or equivalent non-card meta).
- (R3) Storage room fields are icon + `Label:` + value rows that wrap; no bordered info tiles in that section.
- (R4) Add shelf appears in the Shelves section **header**, left of the chevron; not duplicated in the body; write-gated.
- (R5) Shelves list is an `AppListTable` with search/settings (and filter if standard), columns for shelf id, name, status, actions.
- (R6) Row Edit/Delete are borderless icon+label; Delete destructive; Edit/Delete still open existing shelf flows and refresh the dialog.
- (R7) Footer Close / Delete|Restore / Edit room unchanged in behavior and gating.
- (R8) Empty shelves and soft-deleted room states still behave correctly.

## Verification

- Widget/source tests or golden-friendly pumps: title string; no hero; Storage room not using `AppInfoTileGrid`; Shelves `headerActions` contains Add shelf; body uses `AppListTable`; footer actions still present.
- Manual: Catalog → Rooms → open Room 1 — confirm layout vs screenshots’ *intended* target; Add shelf from header; search shelves; Edit/Delete shelf; Edit/Delete room; narrow width; light + dark.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart` — `_StorageRoomDetailsDialog`, `_StorageRoomShelfRow`, `openPharmacyStorageRoomDetailsDialog`
- `frontend/lib/shared/components/app_collapsible_section.dart` — `headerActions` (Add shelf placement)
- `frontend/lib/shared/components/app_list_table.dart` — shelves table chrome
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` — Catalog → Shelves columns/actions as the table pattern reference
- `frontend/lib/l10n/app_en.arb` (+ generated l10n) — add `Room Details` (or reuse an existing details title key if one fits)
- Tests under `frontend/test/features/pharmacy/` as needed for dialog chrome
