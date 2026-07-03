# Facility-scoped lab catalog configuration

## Context

HOSSPI ships a **platform-wide lab test and panel catalog** (LOINC-backed defaults, reference ranges, units, qualitative options). The **Laboratory → Lab Configurations** modal (Tests / Panels tabs) and **Configure lab test** form already expose catalog CRUD and per-test settings (name, code, category, specimen type, result kind, units, qualitative options, description, and age/gender reference ranges).

**Problems today**

- The configurations modal is slow and can overflow while loading the full catalog (including units manifest).
- Catalog edits are effectively **tenant/global**, not **per facility**.
- Lab order / clinical request flows load the full catalog instead of only what the active facility offers.
- Pricing is not enforced at the facility level, so users may still enter costs manually when ordering tests.

## Goal

Let each **facility** choose which platform tests/panels it offers and **override catalog defaults** (including price) for its own operations—without duplicating the master catalog. Clinical and lab users should only see and request **facility-enabled** tests/panels with **pre-set prices**. Configuration remains restricted to authorized admin/lab roles.

## Scope

### 1. Data model (backend + migrations)

Introduce a **facility lab offering** layer (mirror the existing `facility_catalog_offering` / clinical-catalog pattern where practical):

| Concern | Requirement |
|--------|-------------|
| **Offering toggle** | Per facility + test/panel: `is_active`, optional sort order. |
| **Pricing** | Required `unit_price` (+ currency) per offered test and panel at facility scope. Panel price may override sum-of-tests or stand alone—document chosen rule. |
| **Overrides** | Facility may override: specimen type, result kind, default unit, unit options, qualitative options, description. |
| **Reference ranges** | Support **multiple** ranges per offered test with gender, age min/max + unit, normal/critical bounds, reference text. |
| **Defaults** | Seed platform defaults (LOINC / clinical norms) on first enable; facility edits override without mutating global catalog. |
| **Interpretation** | Backend result interpretation must resolve the **facility-specific** range set using patient age and gender (existing `lab.interpretation.js` logic extended, not replaced). |
| **Audit** | All create/update/delete/enable/disable actions require reason where destructive; write audit logs. |

Do **not** break existing tenant-level `lab_test` / `lab_panel` records; treat them as the master catalog.

### 2. Lab Configurations UI (screenshots)

**Entry:** Laboratory module → overflow menu → **Lab Configurations**.

**Tests tab**

- List platform tests with facility status: *offered / not offered*, price, and key overrides.
- Actions: enable/disable for facility, **Configure** (opens existing form extended with price + offering toggle), not global delete unless platform admin.
- Search/filter must stay responsive; **do not load the entire catalog eagerly**—paginate or lazy-load (including units manifest).

**Panels tab**

- Same offering model for panels; panel composition references **facility-offered** tests only.

**Configure lab test dialog** (extend current form)

Add / clarify:

- **Offer at this facility** (toggle)
- **Price per test** (required when offered)
- Keep existing fields: test name, code, category, specimen type, result kind, default unit, unit options, qualitative options, description
- **Reference ranges:** support adding/editing **multiple** rows (gender applicability, age min/max + unit, result unit, normal/critical min/max, reference text)
- Pre-fill reference ranges from platform defaults; show source hint (e.g. “Platform default — editable for this facility”)

**Performance / layout**

- Fix modal overflow on smaller viewports.
- Configurations dialog opens quickly; heavy catalog data loads on demand inside tabs/forms.

### 3. Lab order & clinical request flows

- Test/panel pickers load **only facility-offered, active items** via lightweight search API (typeahead; no full catalog in workspace state).
- Selected tests/panels attach **facility price automatically** to billing/clinical request payload—no manual price entry for standard orders.
- If a test is not offered at the facility, it must not appear in pickers (existing orders with retired offerings remain readable).

### 4. Permissions

| Role / permission | Configurations (read) | Configurations (write) | Order/request (read catalog) |
|-------------------|----------------------|------------------------|------------------------------|
| Platform / super admin | ✓ | ✓ (global + facility) | ✓ offered only |
| Tenant admin | ✓ | ✓ (tenant facilities) | ✓ offered only |
| Facility admin | ✓ | ✓ (own facility) | ✓ offered only |
| Lab team with `lab:write` | ✓ | ✓ (own facility overrides) | ✓ offered only |
| Clinical / lab users without config rights | ✓ read-only effective values | ✗ | ✓ offered only |

Users without write access who need catalog changes should see a clear “contact your lab administrator” message—not editable fields.

### 5. API

- CRUD/list endpoints scoped by `facility_id` for offerings and overrides.
- Separate **lightweight search** endpoint for order pickers (`q`, `limit`, `term_type=LAB_TEST|LAB_PANEL`, `offered_only=true`).
- Existing lab-test endpoints remain for master catalog management; facility endpoints merge master + override for reads.

## Acceptance criteria

- [ ] Facility A and Facility B under the same tenant can offer different test sets and prices.
- [ ] Enabling a test pre-fills reference ranges from platform defaults; facility edits persist without changing other facilities.
- [ ] Result entry flags abnormal/critical results using the **patient-matched** facility reference range (age + gender).
- [ ] Lab Configurations modal loads in under ~2s on demo data; no layout overflow at 1280×720.
- [ ] Create Lab Order / clinical lab request pickers never download the full catalog; search returns only offered items with price.
- [ ] Placing a lab order auto-applies facility test/panel prices to billing.
- [ ] Unauthorized users cannot mutate facility lab configuration; attempts are rejected server-side.
- [ ] Migrations, seeds, and tests cover offering CRUD, override merge, interpretation, and permission checks.

## Implementation notes

- Reuse patterns from `clinical-catalog.service.js` (`facility_catalog_offering`, layered GLOBAL vs FACILITY search) and existing lab modules: `lab-test`, `lab-panel`, `lab.configuration.js`, `lab.interpretation.js`, `frontend/lib/shared/lab_catalog/`.
- Avoid loading `catalogTests` / `catalogPanels` on initial `LabWorkspacePage` load; fetch only when opening configuration or order dialogs.
- Follow existing UI components, l10n keys, and audit conventions.

## Out of scope (for now)

- Cross-facility price templates or bulk import/export.
- Patient-specific negotiated pricing.
- Replacing the master LOINC/platform catalog source.
