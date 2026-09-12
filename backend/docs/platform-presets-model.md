# Platform Presets Model

**Fairbanks fixes — Phase 2, step 06.** How centrally owned master data is
separated from tenant and facility configuration, and the state of the rollout.

## 1. The model

Master data splits in two tiers.

| Tier | Where it lives | Who owns it |
| :--- | :--- | :--- |
| **Definition** | The existing catalog table (`lab_test`, `lab_panel`, `radiology_procedure`, `drug`, `clinical_term_catalog`) | `tenant_id IS NULL` → the platform. A tenant id → that tenant. |
| **Adoption** | The facility offering table (`facility_lab_test_offering`, `facility_lab_panel_offering`, `facility_radiology_procedure_offering`, `facility_pharmacy_offering`, `facility_catalog_offering`) | Always the tenant, keyed unique per facility and definition |

A tenant may read the platform catalog, adopt a preset for one of its
facilities, override the permitted fields on **its own adoption row**, and
create its own definitions. It may never update or delete a platform
definition.

`tenant_id IS NULL` as the platform marker is not new — `role` and `permission`
already use exactly this, so the schema carries one notion of platform scope
rather than two.

### 1.1 Why the adoption row and not the definition

Overrides live on the adoption because the definition is shared. A tenant
changing a price on the definition would change it for every other tenant. The
adoption tables already carried the right fields before this step: price,
currency, availability, sort order, and the local clinical detail each domain
allows.

### 1.2 Permitted overrides per domain

Declared once in [`src/lib/catalog/preset-ownership.js`](../src/lib/catalog/preset-ownership.js)
so the API, tests and UI agree.

| Domain | Definition | Adoption | Tenant may override |
| :--- | :--- | :--- | :--- |
| `lab_test` | `lab_test` | `facility_lab_test_offering` | `is_active`, `sort_order`, `unit_price`, `currency`, `unit`, `description`, `reference_range`, `specimen_type`, `result_kind` |
| `lab_panel` | `lab_panel` | `facility_lab_panel_offering` | `is_active`, `sort_order`, `unit_price`, `currency` |
| `radiology_procedure` | `radiology_procedure` | `facility_radiology_procedure_offering` | `is_active`, `sort_order`, `unit_price`, `currency` |
| `drug` | `drug` | `facility_pharmacy_offering` | `is_active`, `sort_order`, `unit_price`, `currency`, `default_storage_shelf_id` |
| `clinical_term_catalog` | `clinical_term_catalog` | `facility_catalog_offering` | `is_active`, `sort_order` |

The naming field and `code` are never overridable — they are the identity a
shared preset is recognised by, and a local rename would make the catalog unsafe
to share.

`clinical_term_catalog` permits no price override, because a diagnosis is not
sold and `facility_catalog_offering` carries no price column. Its adoption is
keyed `(facility_id, term_type, item_id)` rather than by a single FK, since one
offering table serves diagnoses, procedures and the rest.

## 2. Enforcement

Three guards, all in `preset-ownership.js`, applied in the service layer so the
API rejects rather than the UI hiding:

| Guard | Behaviour |
| :--- | :--- |
| `assertCanMutatePresetDefinition` | Tenant actor updating or deleting a platform definition → `403 errors.auth.insufficient_permissions`. Tenant actor touching another tenant's definition → `403 errors.auth.scope_mismatch`. |
| `resolvePresetDefinitionScope` | `scope: 'platform'` requires platform authority. Otherwise the definition is pinned to the actor's own tenant, whatever `tenant_id` the body claims. |
| `assertAdoptionOverridesAllowed` | A field outside the domain's `overridable` list → `422 errors.catalog.preset.not_overridable`. |

### 2.1 Trusted internal callers

Seeders, backfills and service-to-service calls arrive without the
`permissions` array that `auth.middleware` attaches to every HTTP request, and
are allowed through. This is the same signal `assertCanAccessTenantRecord` in
the tenant module already uses. Because the middleware always normalises
`permissions` to an array, **no request can reach a guard as an internal
caller** — verified in `preset-ownership.test.js`.

## 3. Rollout state

### 3.1 Landed

| Item | State |
| :--- | :--- |
| Ownership model + guards | ✅ `src/lib/catalog/preset-ownership.js` |
| Referrer graph, parsed from the schema | ✅ `src/lib/catalog/preset-references.js` |
| Platform catalog seeder (2,169 presets) | ✅ `scripts/seed-platform-presets.js`, seeded on development |
| Duplication survey, read-only | ✅ `scripts/analyze-catalog-duplication.js` |
| Unit tests (41) | ✅ `src/tests/lib/catalog/preset-ownership.test.js` |
| Schema: platform scope | ✅ `lab_test`, `lab_panel`, `radiology_procedure`, `drug`, `clinical_term_catalog` |
| Migration | ✅ `20260912020000_platform_preset_scope`, applied to development |
| Enforcement: lab tests | ✅ service + controller |
| Enforcement: lab panels | ✅ service + controller |
| Enforcement: radiology procedures | ✅ service + controller |
| Enforcement: drugs / pharmacy | ✅ service + controller, plus a read-visibility fix (below) |
| Enforcement: clinical terms | ✅ service + controller, 403 instead of a silent 404 |
| Cross-domain immutability tests (11) | ✅ `src/tests/modules/catalog/platform-preset-immutability.test.js` |

The migration only relaxes `NOT NULL`. Every existing row keeps its `tenant_id`,
so it is behaviour-preserving on its own — deduplication is a separate,
reviewable backfill.

### 3.2 Remaining

All five domains above now have both tiers. `facility_catalog_offering` already
existed and serves clinical terms, so no new adoption table was needed for them.

| Item | Requirement |
| :--- | :--- |
| Collapse tenant rows onto presets (§5.3) | R6 |
| Adoption API — browse, adopt, customise, facility-specific entries | R3 |
| New tables: currency preset + tenant adoption | R2 |
| New tables: consultation type preset + facility adoption | R2 |
| Dedup backfill preserving order references | R6 |
| Frontend catalog surfaces | R7, AC6 |
| Production migration and rollout | R9, AC8 |

### 3.3 Deliberate exclusions

| Domain | Decision |
| :--- | :--- |
| `procedure`, `diagnosis` | **Not master data.** Both are encounter-scoped operational records (`encounter_id`, no tenant). Theatre procedures and clinical diagnoses as *catalog* live in `clinical_term_catalog` under `ClinicalTermType.PROCEDURE` / `DIAGNOSIS`, which is what this step treats. |
| `unit`, `department` | **Facility structure, not presets.** Created per facility, referenced by staffing and scheduling. Folding them into a shared platform catalog would conflict with the model above. The related problem — the HR workspace lazily creating 20 departments and 20 units on a read — is recorded in [tenant-initialization-audit.md](tenant-initialization-audit.md) §5.2 and belongs to that fix, not this one. |

### 3.4 A read-visibility bug found on the way

`findScopedDrugOrThrow` compared `String(drug.tenant_id || '')` against the
actor's tenant. A platform preset has `tenant_id: null`, which stringifies to
`''`, so it never matched a tenant actor and the API returned **404** — a tenant
could not see a platform drug at all, let alone adopt it.

Reads now treat a platform definition as visible to everyone while writes stay
refused. Visibility is not permission: `assertCanMutatePresetDefinition` is what
decides the write, and it is tested separately.

The drug list had the same shape of problem for a different reason: its search
filter owns the top-level `OR`, so putting visibility in a bare `OR` would have
been silently overwritten and widened the query across tenants. Visibility is
composed under `AND` instead.

## 4. The platform catalog

[`scripts/seed-platform-presets.js`](../scripts/seed-platform-presets.js)
(`npm run db:seed:platform-presets`) writes the centrally owned tier from the
curated Uganda clinical catalogs that already ship in the repo.

| Domain | Presets | Source |
| :--- | ---: | :--- |
| `lab_test` | 147, with 91 unit options, 442 reference ranges and 180 result options | `scripts/seeders/data/uganda-lab-catalog.js` |
| `lab_panel` | 40, with 351 panel items | same |
| `radiology_procedure` | 146 | `scripts/seeders/data/uganda-radiology-catalog.js` |
| `drug` | 100 | `DRUG_CATALOG` in `seed-clinical-catalog-pack.js` |
| `clinical_term_catalog` | 1,736 diagnoses | `scripts/seeders/data/uganda-diagnosis-catalog.js` |

A lab test's unit options, reference ranges and result options are **clinical
standards, not commercial terms**, so the platform definition owns them — a
platform preset arrives complete and usable. A facility needing a local
variation gets one through the facility-level equivalents on its offering
(`facility_lab_test_reference_range` and friends), which is what those tables
are for.

Panel items and the three lab-test child tables are written as nested creates on
their parent. None of them carries `human_friendly_id`, and a direct
`prisma.<model>.create` would trip the client extension that assumes every model
does — see §6.

Rows carry deterministic ids derived from their catalog key, so a re-run updates
in place. Verified on development across three consecutive full runs: every
domain reports `0 created`, and the underlying row counts do not move
(`lab_test` 294, `lab_test_reference_range` 884, `lab_panel_item` 959, and so
on). Nothing is deleted and no tenant-owned row is touched.

**This is not demo data and is deliberately not behind `demo-safety.js`.** The
platform catalog is reference data production needs for the preset model to mean
anything: a tenant cannot adopt a preset that does not exist. The rows carry no
patient or tenant information. `seed-demo-data.js` stays gated as before.

Platform definitions carry **no price** — `unit_price` and `currency` are left
null. Price is a tenant concern and belongs on the facility offering.

## 5. What the migration actually has to do

### 5.1 The duplication R6 assumes does not exist

Step 06's R6 asks to "migrate existing per-tenant duplicated master data onto the
preset model". Surveyed with
[`scripts/analyze-catalog-duplication.js`](../scripts/analyze-catalog-duplication.js)
(`npm run db:analyze:catalog-duplication`, read-only), **there was no
cross-tenant duplication in either environment**:

| Environment | Finding |
| :--- | :--- |
| Development | All 147 lab tests, 105 panels, 146 radiology procedures, 100 drugs and 189 clinical terms belonged to a single tenant — the seeded `DemoCare`. Zero duplicate groups. |
| Production | Same shape: everything in `DemoCare`, plus exactly **one** drug in `FAIRBANKS MEDICAL CENTRE`. Zero duplicate groups. |

So the master data was never duplicated across tenants — it was concentrated in
one seeded tenant, and no platform tier existed at all. The job was therefore
**promotion**, not deduplication: publish the curated catalog at platform scope,
then let tenant rows collapse onto it.

That is why the platform seeder above seeds from the curated source files rather
than promoting the demo tenant's rows. Promoting them would have entangled the
platform tier with the demo dataset, so clearing demo data would take the
platform catalog with it.

### 5.2 What is now collapsible

With the platform tier seeded, development shows:

| Domain | Platform | Tenant | Collapsible |
| :--- | ---: | ---: | ---: |
| `lab_test` | 147 | 147 | 147 |
| `lab_panel` | 40 | 105 | 31 |
| `radiology_procedure` | 146 | 146 | 146 |
| `drug` | 100 | 100 | 100 |
| `clinical_term_catalog` | 1,736 | 189 | 189 |
| **Total** | **2,169** | **687** | **613** |

One group conflicts and needs a human decision rather than a silent merge:
`lab_panel` `code:fever` has two rows in one tenant differing on `category`. The
analysis reports conflicts instead of guessing.

### 5.3 The collapse is the risky part, and is not written yet

Retiring a tenant row onto a platform preset must repoint every reference to it.
The referrer graph is derived from `schema.prisma` by
[`preset-references.js`](../src/lib/catalog/preset-references.js) rather than
hand-listed, so a table added later is picked up automatically:

| Domain | Operational referrers | Rows pointing at tenant copies (dev) |
| :--- | :--- | ---: |
| `lab_test` | `lab_order_item`, `lab_panel_item`, `lab_qc_log` | 1,611 |
| `lab_panel` | — (`lab_panel_item` cascades) | 608 |
| `radiology_procedure` | `radiology_order` | 1,001 |
| `drug` | `pharmacy_order_item`, `drug_batch`, `drug_inventory_map`, `formulary_item`, `adverse_event` | 1,508 |
| `clinical_term_catalog` | none | 0 |

Two hazards the collapse has to handle, neither of which is solved yet:

1. **Unique constraints on the adoption tables.** `facility_lab_test_offering`
   is `@@unique([facility_id, lab_test_id])`. Repointing a tenant row's offering
   at the platform id collides if that facility already has one, so the collapse
   must merge rather than update blindly.
2. **Cascading children carry local clinical detail.** A tenant's
   `lab_test_reference_range`, `_unit_option` and `_result_option` rows belong to
   its own definition. They have facility-level equivalents
   (`facility_lab_test_reference_range` and friends), so the collapse has to move
   them onto the adoption rather than drop them with the retired row.

Production carries real Fairbanks orders plus DemoCare's seeded volume, so this
runs dry-run first, counted before and after, with a backup taken.

## 6. A latent bug this work surfaced

`withHumanFriendlyIdSupport` in [`src/prisma/client.js`](../src/prisma/client.js)
assigns a `human_friendly_id` on every `create` for every model except
`human_id_counter`. It does not check whether the model actually declares that
column, so a direct `prisma.lab_panel_item.create(...)` fails with
`Unknown argument 'human_friendly_id'`.

It has never surfaced because the codebase only ever writes these join and child
rows as nested creates on their parent, and nested writes do not fire the
extension's `create` hook.

Not fixed here: it is unrelated to the preset model and sits on the write path of
every model, so it deserves its own change rather than being folded into this
one. The fix is a field check against the schema before assigning. Affected
tables include `lab_panel_item`, `lab_test_unit_option`,
`lab_test_reference_range` and `lab_test_result_option`.
