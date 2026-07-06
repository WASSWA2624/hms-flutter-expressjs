# Feature: Pharmacy storage location (rooms & shelves)

## Goal

Let pharmacies record **where drugs are physically stored** so staff can locate stock quickly. Facilities (or pharmacy admins) maintain a catalog of **storage rooms** and **shelf numbers**; when adding or receiving stock, staff optionally assign a shelf. Location should surface on the drug catalog and inventory views—not only in the add dialog.

## Current state (problem)

| Gap | Detail |
|-----|--------|
| **No storage model** | `drug`, `drug_batch`, and `drug_inventory_map` have no room/shelf fields |
| **No management UI** | Pharmacy workspace has no way to create rooms or shelves |
| **Add drug dialog** | `PharmacyDrugEditDialog` covers identity, pricing, stock, and batch metadata—no storage location |
| **Ward `room` is wrong domain** | Existing `room` model is for inpatient wards/beds (`rooms_beds` module)—do **not** reuse for pharmacy storage |

Pharmacy “location” elsewhere (`OUTPATIENT` / `INPATIENT` on orders) refers to **care setting**, not physical shelf location.

## Reference implementation

Mirror the mortuary storage hierarchy (unit → slot → assignment):

| Concept | Mortuary reference |
|---------|-------------------|
| Storage area (room) | `mortuary_storage_unit` — facility-scoped, named, typed |
| Position within area (shelf) | `mortuary_storage_slot` — `slot_code` + optional label, unique per unit |
| Assignment to inventory | `mortuary_storage_assignment` — links case to unit + slot |

**UI patterns:** mortuary workspace lookups (`storage_units`, slot pickers), `AppSelectField` cascades (room → shelf), inline “Add room/shelf” affordance where appropriate.

**Drug dialog patterns:** extend `PharmacyDrugEditDialog` (`frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`) using existing `AppFormSection` / `AppResponsiveFieldRow.two` from the catalog refactor in `prompt.md`.

## Proposed data model

Add **pharmacy-specific** tables (names illustrative—match project naming conventions):

### `pharmacy_storage_room`

| Field | Notes |
|-------|-------|
| `tenant_id`, `facility_id` | Scope to facility |
| `name` | e.g. *Main store*, *Cold chain room* |
| `code` | Optional short code for labels |
| `is_active` | Soft-disable without deleting history |

### `pharmacy_storage_shelf`

| Field | Notes |
|-------|-------|
| `storage_room_id` | Parent room |
| `shelf_code` | Required identifier, e.g. `A-12`, `R3-S5` |
| `label` | Optional friendly name |
| `is_active` | Default true |

**Unique constraint:** `(storage_room_id, shelf_code)`.

### Location on inventory

Store location at the **batch** level (batches can sit on different shelves). Optionally also persist a **default shelf** on the drug or `drug_inventory_map` for new receipts.

| Attach to | Fields | When |
|-----------|--------|------|
| `drug_batch` | `storage_room_id`, `storage_shelf_id` (nullable FKs) | Initial stock on add; editable on batch adjust |
| `drug` or `facility_pharmacy_offering` | default `storage_shelf_id` (optional) | Pre-fill shelf on next receipt |

Prefer nullable FKs over free-text shelf strings so labels stay consistent and searchable.

## UI scope

### 1 — Storage catalog management *(new, facility-scoped)*

Minimal CRUD reachable from pharmacy settings or a “Storage layout” panel:

- List rooms for the current facility; add / rename / deactivate.
- Per room: list shelves; add shelf codes; deactivate unused shelves.
- Do not block drug workflows if catalog is empty—location remains optional.

**Permissions:** facility admin or pharmacist role (align with existing pharmacy workspace auth).

### 2 — Add / edit drug dialog *(extend existing dialog)*

Add **Section — Storage location** *(add flow and batch receive; optional on edit if batch location is editable)*:

| Field | Component | Required | Notes |
|-------|-----------|----------|-------|
| Storage room | `AppSelectField` | No | Options from facility catalog; “None” clears shelf |
| Shelf | `AppSelectField` | No | Filtered by selected room; disabled until room chosen |

Row: **room** + **shelf**.

- Changing room clears shelf if the current shelf is not in the new room.
- Helper text (muted): *Optional—helps staff find this drug on the floor.*
- If room catalog is empty, show a compact empty state with link/action to add rooms (or defer to settings—pick one consistent pattern).

### 3 — Catalog & inventory display *(read-only surfacing)*

- Drug catalog row / detail: show `Room / Shelf` when set (e.g. *Main store · A-12*).
- Batch or stock views: show batch shelf; allow filter/search by room or shelf code.

Keep scope tight: management CRUD + dialog fields + catalog column/filter. Full warehouse map visualization is out of scope.

## Backend parity

Extend end-to-end—no UI-only fields:

| Layer | Changes |
|-------|---------|
| Prisma | New models + optional FKs on `drug_batch` (and default on drug/offering if adopted) |
| Schemas | Zod create/update for rooms, shelves, and `setupPharmacyDrugSchema` / batch payloads |
| Service | `pharmacy-workspace.service.js` — room/shelf CRUD, include lookups in workbench/catalog responses |
| Serializer | Return `storage_room_id`, `storage_room_label`, `storage_shelf_id`, `storage_shelf_code` on drugs/batches |
| Frontend entities | `PharmacyDrugInput`, batch DTOs, lookup options on workspace state |

**Validation:**

- Shelf must belong to the selected room.
- Deactivating a room/shelf must not break historical batch records (soft-delete / `is_active` only).
- Location fields remain optional on create.

## Implementation rules

- **Do not reuse ward `room`** or mortuary tables—pharmacy storage is its own domain.
- **Reuse shared components** (`AppSelectField`, `AppFormSection`, mortuary-style lookup wiring).
- **Localization:** keys in `frontend/lib/l10n/app_en.arb` for section title, room/shelf labels, empty states, and catalog column header.
- **Follow-on to `prompt.md`:** assume the grouped drug dialog already exists; add Section — Storage location without regressing batch/pricing work.
- **Migration:** include seeder-friendly sample room/shelf for dev if other modules do.

## Acceptance criteria

- [ ] Facility can create pharmacy storage rooms and shelf codes; shelves are unique per room.
- [ ] Add-drug (initial stock) flow optionally assigns room + shelf; values persist on the created batch.
- [ ] Room and shelf selects cascade correctly; both fields are optional.
- [ ] Drug catalog or inventory list displays stored location when present.
- [ ] API returns room/shelf labels for display without extra client joins.
- [ ] Ward/inpatient `room` model and pharmacy order “location” filter are unchanged.
- [ ] Deactivated rooms/shelves are hidden from pickers but retained on historical batches.
