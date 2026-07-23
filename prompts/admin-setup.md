# Admin Setup — Clinical Services catalog (global + per-facility configure)

Refine the **Clinical Services** desk tab on `/admin/setup` so it manages the **global clinical catalog**, with nested category tabs and a separate **Configure** flow to attach offerings to tenants/facilities.

Use existing setup patterns from `screens/admin-setup.md` and shared table/dialog components (`AppTabStrip`, `AppListTable`, Filter / Settings, `AppConfirmActionDialog`, etc.). Prefer extending `FacilityCatalogConfigPanel` (and related lab/radiology/clinical catalog dialogs) over inventing a parallel UI.

---

## Goal

Admins should be able to:

1. **Browse and CRUD the global catalog** for three clinical categories (independent of which facility is currently selected).
2. **Configure** which of those catalog items a given tenant/facility may offer (enable/price/scope), via a Configure dialog that asks for tenant + facility.

Tenants/facilities then only see what was configured for them when ordering services.

---

## Scope — nested tabs

Under the existing **Clinical Services** desk section, replace (or reshape) the inner category strip so these three nested tabs appear in the same toolbar/table-chrome area as other setup lists:

| Nested tab | Catalog content |
| ---------- | --------------- |
| **Radiology** | Radiology procedures / tests |
| **Lab** | Lab tests and panels |
| **Diagnoses** | Clinical diagnosis terms / categories a facility may configure |

Do **not** require a pre-selected facility to view these tables. The lists are the **full available catalog**, not the current facility’s enabled offerings only.

(If Procedures / Prescriptions / Budget remain elsewhere, keep them out of this change unless needed for consistency; this prompt’s focus is Radiology, Lab, Diagnoses.)

---

## Per-tab table chrome (same for all three)

Each nested tab uses `AppListTable` with:

| Control | Behavior |
| ------- | -------- |
| **Search** | Text search over catalog rows |
| **Filter** | Advanced filters appropriate to the category (e.g. lab type/category, radiology modality, diagnosis grouping) |
| **Settings** | Column visibility |
| **Configure** | Search-bar trailing (and empty-state primary where appropriate) — opens the **per-tenant/facility configure** dialog (see below) |
| **Add** | Create a new global catalog item for that category |
| **Edit** / **Delete** | Row actions on every mutable catalog row |

CRUD applies to the **global catalog item** (e.g. add/edit/delete a lab test definition), not only to a facility offering link.

Pagination/column patterns should match Tenants / Facilities / structure tabs.

---

## Configure flow (tenant / facility scoping)

**Configure** does **not** filter the main table by facility. The main table stays global.

When the user clicks **Configure**:

1. Open a dialog that lets them **select tenant and facility** (and any category-specific enable options already used elsewhere, e.g. price for lab/radiology).
2. From that dialog, browse/select catalog items and **enable / update / disable** offerings for the chosen facility (reuse or adapt `LabEnableFacilityOfferingDialog`, `RadiologyEnableFacilityOfferingDialog`, and diagnosis/clinical offering upsert patterns where they fit).
3. After configure succeeds, refresh only what that dialog owns; do not silently switch the desk table into “facility-only” mode.

Result: facilities only access procedures/services that were configured for them; the Clinical Services desk table continues to show the full catalog.

---

## Category-specific expectations

### Radiology

- Table: all configurable radiology procedures.
- Add / Edit / Delete procedure definitions in the global catalog.
- Configure: enable procedures for a selected tenant/facility (price/modality filters as in existing radiology enable dialogs).

### Lab

- Table: all lab **tests** and **panels**.
- Add / Edit / Delete tests and panels in the global catalog.
- Configure: enable test or panel for a selected tenant/facility (reuse enable-test / enable-panel patterns with price).

### Diagnoses

- Table: all configurable diagnosis terms/categories for the catalog.
- Add / Edit / Delete diagnosis catalog entries.
- Configure: attach/enable diagnoses for a selected tenant/facility so clinical workflows only surface what that facility configured.

---

## UX / permissions alignment

- Place nested tabs where section toolbars already live (same pattern as other setup desk tabs).
- Gate visibility with existing setup permissions (`canManageFacility || canManageTenant` for Catalog), consistent with `screens/admin-setup.md`.
- Soft-delete / confirm patterns should match other setup entities where delete is supported.
- Keep copy and footer labels consistent with existing l10n keys; add keys only when needed.

---

## Out of scope (unless already broken)

- Reworking Tenants / Facilities / structure / Roles / Users tabs.
- Mounting `TenantFacilitySetupWizard` (still unused from this route).
- Changing clinical order-entry pickers beyond consuming the configured facility offerings.

---

## Acceptance criteria

- [ ] Clinical Services shows nested tabs: **Radiology**, **Lab**, **Diagnoses**.
- [ ] Each tab lists the **global** catalog (not blocked on “select a facility first”).
- [ ] Each table has **Filter**, **Settings**, **Configure**, plus **Add** and row **Edit** / **Delete**.
- [ ] **Configure** opens a flow that selects **tenant + facility** and enables/updates offerings for that scope.
- [ ] Global CRUD and facility configure are clearly separated: table = catalog definitions; Configure = facility offerings.
- [ ] Behavior and chrome match other `/admin/setup` list tabs; reuse shared lab/radiology/clinical catalog dialogs where possible.

---

## Primary files to touch

- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (facility-required empty state — relax for catalog browse)
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart`
- Related clinical diagnosis catalog APIs/dialogs under `shared/clinical_actions/` as needed
- `screens/admin-setup.md` — update the Clinical Services inventory after implementation
