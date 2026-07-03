# Facility-Scoped Lab Catalog — Implementation Prompt

## Objective

Implement **per-facility lab catalog offerings** for HOSSPI HMS. Each facility selects which platform tests and panels it runs, overrides operational defaults (including price and reference ranges), and exposes only those items in lab order and clinical request flows—with prices applied automatically at order time.

**Architecture:** Keep tenant-level `lab_test` / `lab_panel` as the **master catalog** (LOINC-backed). Add a **facility offering layer** that toggles availability, stores facility price, and holds overrides—mirroring `facility_catalog_offering` / `clinical-catalog.service.js` patterns. Never mutate master records when a facility customizes its offering.

---

## Problems to Solve

| Issue | Required outcome |
| ----- | ---------------- |
| Lab Configurations modal loads the full catalog (incl. units manifest) → slow, overflows UI | Paginate or lazy-load; open modal in < ~2s; no overflow at 1280×720 |
| Catalog edits are tenant/global | All operational config scoped to active `facility_id` |
| Order/clinical pickers load full catalog | Lightweight typeahead over **offered-only** items |
| Manual price entry on orders | Facility `unit_price` auto-attached to billing payload |

---

## Deliverables

### 1. Data model & backend

Introduce `facility_lab_offering` (or equivalent) linked to facility + master test/panel:

| Field / concern | Rule |
| ---------------- | ---- |
| Toggle | `is_active`, optional sort order per facility + test/panel |
| Pricing | Required `unit_price` + currency when offered. **Panel price is standalone** (not sum-of-tests)—document in API/schema comments |
| Overrides | Specimen type, result kind, default unit, unit options, qualitative options, description |
| Reference ranges | Multiple rows per offered test: gender, age min/max + unit, normal/critical bounds, reference text |
| Defaults on enable | Seed from platform defaults; facility edits persist locally only |
| Interpretation | Extend `lab.interpretation.js` to resolve **facility-specific** ranges by patient age + gender |
| Audit | Reason required on destructive actions; audit all create/update/delete/enable/disable |
| Master catalog | Unchanged; existing `lab_test` / `lab_panel` CRUD remains for platform admins |

**Merge reads:** Facility endpoints return master + offering merged (reuse `facility-lab-catalog.merge.js` pattern).

### 2. API

| Endpoint | Purpose |
| -------- | ------- |
| Facility-scoped CRUD/list | Offerings and overrides by `facility_id` |
| Lightweight search | `q`, `limit`, `term_type=LAB_TEST\|LAB_PANEL`, `offered_only=true` for pickers |
| Master catalog endpoints | Unchanged for global catalog management |

Enforce RBAC + facility scope server-side on every mutation.

### 3. Lab Configurations UI

**Entry:** Laboratory → overflow → **Lab Configurations**

| Tab / dialog | Behavior |
| ------------ | -------- |
| **Tests** | List platform tests with offered/not offered, price, key overrides. Enable/disable, **Configure** (extend existing form). No global delete unless platform admin. Search/filter responsive; no eager full-catalog load |
| **Panels** | Same offering model; composition uses **facility-offered** tests only |
| **Configure lab test** | Add: *Offer at this facility* toggle, **Price per test** (required when offered). Keep existing fields. **Multiple reference-range rows** with platform-default pre-fill and source hint. Fix modal overflow |

Do **not** load `catalogTests` / `catalogPanels` on initial `LabWorkspacePage` mount—fetch on configuration or order dialog open only.

### 4. Lab order & clinical request flows

- Pickers: facility-offered, active items only via search API (typeahead)
- Selected items carry facility price into billing/clinical request payload—no manual price for standard orders
- Retired offerings stay readable on existing orders but never appear in pickers

### 5. Permissions

| Role | Config read | Config write | Order picker |
| ---- | ----------- | ------------ | ------------ |
| Platform / super admin | ✓ | ✓ global + facility | offered only |
| Tenant admin | ✓ | ✓ tenant facilities | offered only |
| Facility admin | ✓ | ✓ own facility | offered only |
| Lab (`lab:write`) | ✓ | ✓ own facility overrides | offered only |
| Others | read-only effective values | ✗ | offered only |

Read-only users see “contact your lab administrator”—not editable fields.

---

## Acceptance Criteria

- [ ] Facility A and B (same tenant) can offer different tests/panels and prices
- [ ] Enabling a test pre-fills reference ranges from platform defaults; facility edits do not affect other facilities
- [ ] Result entry flags abnormal/critical using patient-matched **facility** reference range (age + gender)
- [ ] Lab Configurations modal loads in < ~2s on demo data; no layout overflow at 1280×720
- [ ] Lab order / clinical request pickers never download full catalog; search returns offered items with price
- [ ] Lab orders auto-apply facility test/panel prices to billing
- [ ] Unauthorized config mutations rejected server-side
- [ ] Migrations, seeds, and tests cover offering CRUD, override merge, interpretation, permissions

---

## Reuse & Reference

| Area | Path |
| ---- | ---- |
| Clinical offering pattern | `backend/src/modules/clinical-term/services/clinical-catalog.service.js` |
| Facility lab module | `backend/src/modules/facility-lab-catalog/` |
| Merge logic | `backend/src/modules/lab-workspace/services/facility-lab-catalog.merge.js` |
| Lab config / interpretation | `lab.configuration.js`, `lab.interpretation.js` |
| Frontend catalog | `frontend/lib/shared/lab_catalog/` |
| UI standards | `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`; l10n in `app_en.arb` |

---

## Out of Scope

- Cross-facility price templates or bulk import/export
- Patient-specific negotiated pricing
- Replacing the master LOINC/platform catalog source

---

## Quality Gate

- **Backend:** targeted `npm test` for `facility-lab-catalog`, merge, interpretation
- **Frontend:** `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` for touched modules
