# Tenant Setup — Separate Entity Steps & Full CRUD

## Objective

Refine **Tenant and facility setup** (`/admin/setup`) so each organizational entity has its **own guided step and dedicated modal** with complete create, edit, and delete flows. Replace the current combined steps (“Departments and units”, “Wards, rooms, and beds”) with a **strict chronological hierarchy** where each step unlocks the next.

**Context:** User is already authenticated as tenant or facility administrator. Match existing modal patterns (Tenant profile, Facility profile, Departments list) shown in the current UI.

**Broader module context:** [prompts/03-tenant-facility-module-prompt.md](prompts/03-tenant-facility-module-prompt.md)

---

## Current State

| Area | Today | Gap |
|------|-------|-----|
| Guided setup | 4 steps; steps 3–4 group multiple entities | Split into one step per entity type |
| Modals | Tenant, Facility, Departments, Wards exist | Branches, Units, Rooms, Beds need equal first-class modals |
| Wizard routing | Step 3 → Departments; step 4 → Wards only | Each step opens its own modal |
| Checklist | 4 items; “Departments and units” combined | One checklist item per entity |
| Toolbar chips | Branches, Units, Rooms, Beds reachable | Keep as shortcuts; wizard must mirror them |

**Key files:** `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`, `tenant_facility_setup_wizard.dart`, `tenant_facility_setup_helpers.dart`

---

## Target Entity Hierarchy

```
Tenant
└── Branches (optional)
    └── If no branches exist, the facility acts as both facility and branch
└── Facility
    └── Departments (facility pre-selected when only one exists)
        └── Units (optional)
            └── Wards (require ≥1 department)
                └── Rooms (require parent ward OR department)
                    └── Beds (require parent room or ward)
```

### Parent rules

| Entity | Required parent | Optional parent / scope |
|--------|-----------------|-------------------------|
| Branch | Tenant | May link to a facility |
| Facility | Tenant | When branches exist, treat each facility as a branch |
| Department | Facility | Facility selector hidden/defaulted when only one facility |
| Unit | Department | Optional — skip when not needed |
| Ward | Department | Block creation when no departments exist |
| Room | Facility | Attach to **ward** (inpatient) **or department** (e.g. OPD consult rooms) |
| Bed | Ward | Prefer room when rooms exist; `roomId` optional per existing schema |

---

## Guided Setup Steps (in order)

Replace `TenantFacilitySetupWizardStep` with **8 sequential steps**:

1. **Tenant profile** — name, slug, active
2. **Branches** — optional; show “skip” when single-site; if empty, facility inherits branch role
3. **Facility identity** — name, type, logo, contacts, address
4. **Departments** — list + add/edit/delete modal per record
5. **Units** — optional; list + add/edit/delete; gated on departments
6. **Wards** — list + add/edit/delete; gated on departments
7. **Rooms** — list + add/edit/delete; parent = ward or department
8. **Beds** — list + add/edit/delete; gated on wards

Each step shows completion state (checkmark), opens its modal on tap, and **Continue setup** advances to the next incomplete step.

---

## UI / UX Requirements

- **One modal per entity type** — same `_SetupDetailDialog` / `AppWorkspaceMutationDialog` pattern as Tenant profile and Departments; no route navigation.
- **Full CRUD** — searchable list, **+ Add**, edit (pencil), delete (trash) for Departments, Units, Wards, Rooms, Beds, and Branches.
- **Prerequisite gates** — disable “Add” and show a short inline reason when the parent entity is missing (e.g. “Create at least one department before adding wards”).
- **Smart defaults** — auto-select the sole facility/department/ward in create forms when only one option exists.
- **Checklist** — expand from 4 to 8 items aligned with wizard steps; body text reflects `N of 8 setup areas complete`.
- **Permission gates** — preserve existing Tenant administrator / Facility administrator summary; gate write actions with `AccessGate` / `AppAccessActionGate`.
- **i18n** — all new labels and gate messages in `app_en.arb`; no hardcoded strings.
- **Realtime refresh** — after any mutation, refresh snapshot, wizard completion, checklist, and toolbar chips.

---

## Backend / Data

- Reuse existing CRUD APIs (`tenant`, `facility`, `branch`, `department`, `unit`, `ward`, `room`, `bed`).
- Enforce parent validation server-side (mirror frontend gates).
- No duplicate master data in clinical modules — structure remains owned here per module prompt §Central rule.

---

## Acceptance Criteria

- [ ] Guided setup lists 8 separate steps; none combine multiple entity types.
- [ ] Each entity type has a dedicated modal with search, add, edit, and delete.
- [ ] Wards cannot be created without departments; beds cannot be created without wards.
- [ ] Rooms can be created under a ward or directly under a department.
- [ ] Optional branches: empty branch list does not block facility setup; facility serves as implicit branch.
- [ ] Checklist and wizard completion states stay in sync after CRUD operations.
- [ ] `flutter analyze` and relevant tests pass.

---

## Quality Gate

```sh
cd frontend && flutter pub get && dart format --set-exit-if-changed . && flutter analyze && flutter test
cd backend && npm test -- --testPathPattern="tenant|facility|branch|department|unit|ward|room|bed"
```
