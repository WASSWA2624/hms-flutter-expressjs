# Feature: Facility-scoped radiology configuration (mirror lab flow)

## Goal

Implement a **radiology configuration flow that matches the existing lab configuration pattern** (see attached screenshots). Users who configure radiology for a facility should work from a **platform catalog** and enable only the procedures relevant to that facility—with facility-specific pricing—rather than rebuilding the catalog from scratch.

## Reference implementation

Use the lab configuration UX and architecture as the template:

1. **Lab Configurations** — tenant/facility scope selectors, facility offerings table (search, filters, edit/delete), **Enable test** action.
2. **Enable Lab Offering** — browse the platform catalog; items already offered show **Already offered**.
3. **Enable Test** — confirm selection and set **unit price** + currency before saving.

Mirror this three-step pattern for radiology procedures/tests.

**Primary references:**

- Frontend: `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` (`_LabConfigurationsScopeSection`, scope init via `AppAccessPolicy`)
- Permissions: `frontend/lib/core/permissions/access_policy.dart`
- Shared UI: `frontend/lib/shared/components/app_select_field.dart`, `app_section_panel.dart`, `app_responsive_field_row.dart`

## Entry point

From the radiology workspace overflow menu, **Configurations** opens the radiology configuration dialog (same placement and behavior as lab).

## Scope selection (first screen in dialog)

Resolve **tenant** and **facility** from the user’s access profile. UI visibility follows a strict three-tier model; scope is always fully resolved before data loads, even when selectors are hidden.

| User access | Tenant selector | Facility selector | Scope resolution |
|-------------|-----------------|-------------------|------------------|
| **Platform admin** (all tenants, e.g. superadmin / elevated) | **Shown** — user must pick tenant | **Shown after tenant** — disabled until tenant is selected; enabled once tenant is chosen | `tenantId` from selection → `facilityId` from selection |
| **Tenant admin** (single tenant) | **Hidden** — tenant auto-selected from session/policy | **Shown** — user picks facility within their tenant | `tenantId` from `AppAccessPolicy.tenantId` (session) → `facilityId` from selection |
| **Facility user** (single facility, no tenant choice) | **Hidden** | **Hidden** — facility (and tenant) known from session | `tenantId` + `facilityId` from `AppAccessPolicy` / session; show read-only context label only |

### Scope UX rules

- **Platform admins:** Tenant dropdown first. Facility dropdown stays disabled with a “select tenant first” hint until a tenant is chosen. Changing tenant clears facility and reloads facility options for that tenant.
- **Tenant admins:** No tenant dropdown. Facility dropdown lists only facilities in their tenant.
- **Facility users:** No selectors. Show a compact context label such as *“Configuring radiology catalog for {facility}.”*
- Do **not** load facility offerings until `tenantId` and `facilityId` are both resolved (explicitly or implicitly).
- Reload the facility catalog whenever tenant or facility changes.

### Scope logic (reuse, do not duplicate)

Mirror lab’s `_showTenantSelector`, `_showFacilitySelector`, `_showScopeContextLabel`, and `_initializeScope` patterns. Prefer extracting or reusing a **shared scope widget/helper** (e.g. generalize `_LabConfigurationsScopeSection` into `frontend/lib/shared/`) rather than copying scope UI into radiology.

## Main dialog: Radiology Configurations

Once scope is ready, display the **facility’s enabled radiology procedures** in a searchable, filterable table.

**Required capabilities:**

- Search across procedure name, code, modality/category, and related metadata.
- **Laboratory-style filters** (adapted for radiology: modality, category, etc.).
- Table column settings (visibility).
- Row actions: **Edit** and **Delete** (remove from facility offerings).
- Primary action: **Enable procedure** (or equivalent label)—opens the platform catalog picker.

Columns should include at minimum: procedure name, code, category/modality, and **unit price** (facility currency).

## Enable offering flow (two dialogs)

### 1. Enable radiology offering (catalog picker)

- Lists **platform-level radiology catalog** items the user is allowed to configure.
- Same search + filter affordances as the main table.
- Rows already enabled for the selected facility show **Already offered** and are not selectable again.
- Selecting an available item opens the enable dialog.

### 2. Enable procedure (price confirmation)

- Show selected procedure summary (name, code, modality/category, units if applicable).
- Required **Unit price** field with currency selector (default facility/tenant currency).
- **Cancel** and **Enable procedure** actions.
- On success: close dialogs, refresh facility offerings, show success feedback.

## Edit existing offering

Editing a facility offering should allow updating facility-specific fields (at minimum **unit price** and offered/enabled state), consistent with lab’s configure/edit dialog—not re-creating the platform catalog item.

## Frontend implementation

- Implement radiology configuration in the radiology feature module, **reusing shared components** from `frontend/lib/shared/` wherever they exist (`AppDialog`, `AppSelectField`, `AppSearchBar`, `AppListTable`, form shells, section panels).
- If lab scope UI is generalized, radiology must consume the shared scope component—**do not fork** tenant/facility selector markup.
- Scope visibility must derive from `AppAccessPolicy` (`isElevated`, `canManageTenant()`, `hasFacilityContext`, `tenantId`, `facilityId`)—same rules as lab.
- Introduce a `RadiologyCatalogScope` (or shared `FacilityCatalogScope`) value type mirroring `LabCatalogScope` with `isReady` when both IDs are set.
- All API calls include resolved `tenantId` and `facilityId`; hidden selectors must still send correct scope on every request.

## Backend implementation

- Add or extend radiology catalog/offering endpoints to mirror lab facility-catalog APIs (list offerings, browse platform catalog, enable, update, delete).
- **Enforce scope server-side** on every mutation and read:
  - Platform admins: accept `tenant_id` / `facility_id` from request when authorized; validate facility belongs to tenant.
  - Tenant admins: default or constrain `tenant_id` to session tenant; validate facility is in that tenant.
  - Facility users: ignore client-supplied scope overrides; bind to session `tenant_id` + `facility_id`.
- Reuse existing authorization middleware (RBAC/ABAC + tenant/facility guards) and lab catalog service patterns where applicable.
- Apply Prisma migrations for any new radiology offering tables or columns; keep API contracts aligned with schema.

## Business rules

- **Ordering scope:** Clinicians and request workflows must only see radiology procedures **enabled for their facility**, with the configured facility price.
- **Catalog source:** Configurers browse the **platform catalog**; they do not author new global procedures in this flow.
- **Permissions:** Only users who can configure radiology for a facility may access the platform catalog picker and mutate facility offerings.
- **Parity:** Reuse lab patterns for scope resolution, API shape, loading/empty/error states, and dialog structure wherever possible.

## Acceptance criteria

- [ ] Scope selectors follow the three-tier model (platform admin → tenant then facility; tenant admin → facility only; facility user → hidden, auto-resolved).
- [ ] Facility selector is disabled until tenant is selected for platform admins.
- [ ] Configurations opens scope resolution before showing data; no offerings load until scope is ready.
- [ ] Facility offerings table lists only procedures enabled for the selected facility.
- [ ] **Enable procedure** opens platform catalog picker with search, filters, and “Already offered” state.
- [ ] Enabling a procedure requires a valid unit price; saved price appears in the main table.
- [ ] Edit updates facility offering; delete removes it from the facility (not from platform catalog).
- [ ] Radiology ordering/request flows surface only the selected facility’s enabled procedures and prices.
- [ ] Backend rejects out-of-scope tenant/facility access regardless of client UI.
- [ ] Shared scope/catalog components are reused or extracted—not duplicated per module.
