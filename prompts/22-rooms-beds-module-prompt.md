# Rooms, Wards, and Beds Module — Implementation Prompt

## Objective

Complete the **Rooms, Wards, and Beds Module** for HOSSPI HMS so facility admins and bed managers can manage physical care spaces end-to-end: wards, rooms, beds, bed status, assignments, occupancy visibility, and **IPD bed operations** (assign, release, transfer request) — consuming organizational structure from tenant/facility setup.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Rooms/wards/beds vs Tenant/Facility settings vs IPD
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §3 bed management, §14.2 bed board, statuses, assign/transfer/release
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — indirect; bed ops are post-admit only

**Central rule:** master ward/room/bed structure is owned by **facility catalog** ([prompts/23-tenant-facility-module-prompt.md](./23-tenant-facility-module-prompt.md)). This module focuses on **operational bed board**: status, assignment, and IPD orchestration actions.

---

## Flow Integration Requirements

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Rooms/beds module responsibility |
| ----------- | -------------------------------- |
| §3 Bed statuses | `Available`, `Reserved`, `Occupied`, `Cleaning`, `Maintenance`, `Blocked` |
| Steps 5–6 | Bed request and allocation UI; waitlist when unavailable |
| §9 Transfers | Request transfer; complete with `update-transfer` when API wired |
| Step 18 | Release bed for cleaning after discharge |
| §14.2 Bed board | Live board: ward, room, bed, status, patient, next action |
| §13 Bed manager role | Reserve, allocate, transfer, release |

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Rooms/beds responsibility |
| ----------- | ------------------------- |
| `ADMITTED` | Bed assignment happens in IPD/rooms-beds — not in OPD workspace |
| No OPD mutations | Bed module does not change OPD stages |

### Cross-module

| Module | Integration |
| ------ | ----------- |
| Housekeeping | Bed `Cleaning` → turnover tasks ([prompts/17-housekeeping-module-prompt.md](./17-housekeeping-module-prompt.md)) |
| Operations | `Maintenance`/`Blocked` beds link to maintenance requests ([prompts/16-operations-module-prompt.md](./16-operations-module-prompt.md)) |
| IPD workspace | Patient board + bed board may share data — avoid duplicate bed CRUD |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/rooms_beds/` | Workspace page, controller, repository |
| Catalog CRUD | Via `tenant_facility_repository` | Ward/room/bed save |
| IPD bed ops | `POST /ipd-flows/:id/assign-bed`, `release-bed`, `request-transfer` | Partial wiring |
| Backend | `ward`, `room`, `bed`, `bed-assignment` modules | Master data + assignments |

### Known gaps

- `update-transfer` (approve/complete) not in rooms_beds repository
- Duplicated catalog editing with tenant_facility setup
- No unified live occupancy board with IPD patient board
- Bed suitability rules (gender, isolation, equipment) not enforced in UI
- Deep links `/rooms-beds?ward=` not parsed in router

---

## Scope — Core Capabilities

1. **Bed board** — filter by ward, status; show current patient when occupied/reserved.
2. **Assign / release** — wire IPD bed actions with blocking reasons on failure.
3. **Transfer lifecycle** — request, approve, complete, cancel per ipd-flow §9.
4. **Catalog maintenance** — ward/room/bed CRUD or deep-link to tenant facility setup.
5. **Status coordination** — cleaning/maintenance states with Housekeeping and Operations.

---

## Acceptance Criteria

- [ ] Bed managers can view board and assign/release beds via ipd-flow APIs.
- [ ] Bed statuses align with ipd-flow §3 recommendations.
- [ ] Transfers complete end-to-end when backend supports all steps.
- [ ] No duplicate bed master data definitions vs tenant_facility.
- [ ] Links to IPD admission detail from occupied beds.

---

## Key File References

```
frontend/lib/features/rooms_beds/
frontend/lib/features/tenant_facility/
backend/src/modules/bed/, ward/, room/, ipd-flow/

Related prompts: prompts/05-ipd-module-prompt.md, prompts/23-tenant-facility-module-prompt.md, prompts/17-housekeeping-module-prompt.md
```
