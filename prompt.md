# Facility Details Structure CRUD — Implementation Prompt

## Objective

Complete **full CRUD** for every structure panel inside the **Facility details** dialog (`showFacilityDetailsDialog`), matching the Users panel UX and extending the same pattern to **Branches, Departments, Units, Wards, Rooms, and Beds**.

Create/edit dialogs must be **shared, reusable, and uniform** (usable from Facility details, setup page, and other entry points). After every mutation, counts, lists, and related surfaces must update **instantly** via optimistic patch + realtime reconcile.

Soft delete is the default delete path: rows stay visible as **Deleted**, with **Restore**. Deleting a parent soft-deletes its **descendant structure** in cascade. Operational/clinical surfaces continue to ignore soft-deleted records (`deleted_at IS NULL`).

**Reference UI:** Facility details → Structure sidebar → Users table (Create / Edit / Delete / Restore). Structure panels must behave the same way.

---

## Global Implementation Standards

Follow [`prompts/00-global-implementation-standards.md`](./prompts/00-global-implementation-standards.md) and:

- [`backend/.cursor/prisma.mdc`](./backend/.cursor/prisma.mdc) — soft delete via `deleted_at`; default queries exclude deleted
- [`backend/.cursor/module-creation.mdc`](./backend/.cursor/module-creation.mdc) — service → repository; audit on every mutation
- [`frontend/.cursor/instant_ui_sync.mdc`](./frontend/.cursor/instant_ui_sync.mdc) — optimistic patch + realtime reconcile
- [`frontend/.cursor/realtime_sync.mdc`](./frontend/.cursor/realtime_sync.mdc) — subscribe via `RealtimeEventGroups`
- [`prompts/03-tenant-facility-module-prompt.md`](./prompts/03-tenant-facility-module-prompt.md) — facility catalog owns structure masters
- Modal-first: reuse existing create/edit dialogs; do not invent parallel forms

---

## Hierarchy & Cascade Rules

```
Facility
 └─ Branch (optional parent for org grouping)
 └─ Department
     └─ Unit
 └─ Ward
     └─ Room
         └─ Bed
 └─ Users (facility-scoped membership; not a structural child of dept/ward)
```

### Soft delete cascade (structure only)

| Deleted entity | Also soft-delete (set `deleted_at`) |
|----------------|-------------------------------------|
| Branch | Departments linked to that branch → Units under those departments |
| Department | All Units under that department |
| Unit | Unit only |
| Ward | All Rooms under that ward → all Beds under those rooms / ward |
| Room | All Beds under that room |
| Bed | Bed only |
| User | Soft-delete user + matching `user_permission` rows. Do **not** cascade-delete departments/wards/beds |

### Soft delete must not break the rest of the app

- Default list/select APIs used by OPD, IPD, Nursing, bed board, pickers, etc. continue to filter `deleted_at IS NULL`.
- Soft-deleted structure must not appear in operational dropdowns or assignment flows.
- Only **management** surfaces (Facility details, setup/manage lists) request `include_deleted=true`.
- Cascade is **soft** only — no hard purge of clinical history, encounters, or audit trails.

### Restore rules

- Restoring a parent does **not** auto-restore children (safer, explicit).
- Restoring a child requires its parent chain to be active; otherwise return `409` with a clear message.
- Restore clears `deleted_at`, audits, publishes realtime event, and patches UI instantly.

---

## Required Behavior — Facility Details Dialog

### Shared list UX (all structure panels + Users)

| Element | Requirement |
|---------|-------------|
| Header | Entity title + **Create** action (existing create dialog) |
| Search | Filter current list (include deleted rows) |
| Status | **Active** / **Deleted** badge; muted row styling for deleted |
| Active row actions | **Edit**, **Soft delete** |
| Deleted row actions | **Restore** (Edit disabled) |
| Counts (sidebar) | Structure cards show **active** counts by default |
| Empty / loading | No contradictory loading + empty; responsive mobile / tablet / desktop |

### Create / Edit

Reuse public `showTenantFacility*FormDialog` / Access Admin user dialogs — no Facility-details-only forms.

### Instant UI Sync

After create / update / soft-delete / restore:

1. Optimistically patch Facility details list + structure counts.
2. Patch `tenantFacilitySetup` / overview snapshot providers.
3. Publish scoped backend realtime events (`facility.layout_updated`, `user.*`).
4. Subscribe so setup page and Facility details stay aligned without full-page reload.

---

## Backend API Requirements

For each entity: **user**, **branch**, **department**, **unit**, **ward**, **room**, **bed**:

| Action | Behavior |
|--------|----------|
| `GET` list | Support `include_deleted` for management callers; default `false` |
| `POST` create | Existing create; audit + realtime |
| `PATCH/PUT` update | Existing update; reject updates on soft-deleted rows unless restoring |
| `DELETE /:id` | Soft delete + **cascade soft-delete descendants**; idempotent if already deleted |
| `POST /:id/restore` | Clear `deleted_at` when parent chain is active; audit + realtime |

Workspace aggregators (`tenant-facility-workspace`, `access-admin-workspace`) must honor `include_deleted` for management lists.

---

## Acceptance Criteria

- [x] Each Structure panel has working **Create**, **Edit**, **Soft delete**, and **Restore**.
- [x] Edit opens the **same** reusable form used elsewhere for that entity.
- [x] Soft-deleted rows remain in the management list with **Deleted** status; operational pickers exclude them.
- [x] Soft-deleting a department soft-deletes its units; soft-deleting a ward soft-deletes rooms and beds under it.
- [x] Restore works when parents are active; blocked with clear error when parent is deleted.
- [x] Sidebar structure counts and subscribed surfaces update after CRUD.
- [x] Responsive on mobile, tablet, desktop; localized strings; destructive confirms via `AppConfirmActionDialog`.

---

## Verification

1. Open Facility details → for each structure tab: create → edit → soft delete → confirm Deleted + Restore → restore → Active.
2. Soft-delete a department with units; confirm units show Deleted and vanish from operational unit pickers.
3. Soft-delete a ward with rooms/beds; confirm cascade; attempt restore of a bed while ward is deleted → expect parent-guard error; restore ward then bed.
4. Soft-delete a user; confirm row stays Deleted with Restore; facility user count / access surfaces stay consistent.
5. Hot restart / reconnect: lists and counts still match DB `deleted_at` truth.
