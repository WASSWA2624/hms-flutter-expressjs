# Fix Lab Configurations: catalog loading, enable flow, and role-based access

## Context

In **Laboratory → Lab Configurations** (`/lab`, overflow menu), admins manage the facility lab catalog: enable platform tests/panels for a facility, set prices, and customize reference ranges and result options. Enabled offerings must appear when clinicians create lab orders.

**Observed behavior (super admin, authorized account):**

1. **Transient "Access denied" flash** — On opening Lab Configurations, an "Access denied / You do not have permission" banner appears briefly, then disappears once the dialog settles.
2. **Empty catalog** — Tests and Panels tabs show **"No catalog items found"** even though no offerings have been configured for this facility.
3. **Misleading enable dialog** — **Enable test** / **Enable panel** opens **Enable lab offering**, but shows *"All platform items are already offered at this facility"* despite the catalog being empty. No platform catalog items are selectable.

## Expected behavior

### Catalog loading & UX

- Do **not** show an access-denied (or other error) state to users who are authorized; avoid flashing stale failures while catalog data is loading.
- Show a loading state until platform catalog + facility offering merge completes.
- If the tenant has no master lab tests/panels, show an accurate empty state (not "all already offered").
- Distinguish three states in the enable dialog:
  - **Loading** — fetching catalog
  - **No platform items** — tenant catalog is empty
  - **All enabled** — every platform item already has an active facility offering
  - **Selectable items** — list not-yet-offered tests/panels with facility price input

### Enable & configure flow

- Load the **tenant master catalog** (`lab_test`, `lab_panel`) merged with **facility offerings** via `GET /api/v1/facility-lab-catalog/tests` and `/panels`.
- **Enable lab offering** must list platform items where `is_offered_at_facility === false`, let the admin set a facility price, and persist via `PUT /api/v1/facility-lab-catalog/tests/:id` or `/panels/:id`.
- After enabling, items appear in the Lab Configurations table (with Offered status, price, configure actions) and in lab order catalog search (`offered_only=true`).
- **Configure** existing offerings: reference ranges, result options, specimen, price, activate/deactivate.

### Role-based access & facility scope

| Role | Scope | Enable test/panel | Configure offerings |
|------|-------|-------------------|---------------------|
| **Super admin** (platform) | Any tenant/facility | Yes | Yes |
| **Tenant admin** | All facilities in tenant (support) | Yes | Yes |
| **Facility admin** | Own facility only | No | Yes (own facility) |

- **Enable test** / **Enable panel** actions: visible only to **super admin** and **tenant admin**.
- **Facility admin**: read/configure offerings for their facility; no enable-from-platform action.
- **Super admin** and **tenant admin** must **explicitly select the target facility** before enabling or configuring (visible facility selector + confirmation of active facility context). Facility admins are locked to their facility — show which facility is being configured, read-only.
- Enforce scope on both frontend (hide/disable actions) and backend (`facility-lab-catalog` routes/service, `resolveFacilityId`).

## Likely touchpoints

**Frontend**
- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` — `_openLabConfigurationsDialog`, `_LabConfigurationsDialog`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` — `LabEnableFacilityOfferingDialog` (`_availableItems`, empty-state copy)
- `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart` — `loadFacilityCatalogConfig`

**Backend**
- `backend/src/modules/facility-lab-catalog/` — routes, service (`listFacilityLabTests`, `listFacilityLabPanels`, `upsert*Offering`), merge (`facility-lab-catalog.merge.js`)

## Acceptance criteria

- [ ] Super admin opening Lab Configurations never sees a momentary "Access denied" banner when authorized.
- [ ] Lab Configurations lists tenant platform tests/panels with correct Offered / Not offered status for the selected facility.
- [ ] Enable dialog lists not-yet-offered items when the platform catalog has entries; correct empty copy when catalog is truly empty.
- [ ] Enabling a test/panel with a price creates an active facility offering visible in Lab Configurations and available in lab order creation.
- [ ] Enable actions hidden for facility admin; facility selector shown for super/tenant admin.
- [ ] Backend rejects out-of-scope facility access (403) without causing authorized users to see error flashes.

## Verification

1. Log in as super admin → open Lab Configurations → confirm no error flash, catalog loads.
2. Enable a test and a panel with prices → confirm they appear in the table and in **Create Lab Order** catalog search.
3. Log in as tenant admin → switch facility → enable/configure for a different facility.
4. Log in as facility admin → confirm enable buttons hidden, configure works only for assigned facility.
