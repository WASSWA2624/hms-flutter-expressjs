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

## 4. The backfill is the risky part

Deduplicating per-tenant catalog rows onto shared platform definitions has to
preserve every operational reference:

- `lab_order_item.lab_test_id`
- `radiology_order.radiology_procedure_id`
- `facility_*_offering.<definition>_id`

Production carries real Fairbanks orders plus DemoCare's seeded volume. The
backfill must therefore, per duplicate group: pick or create the platform
definition, repoint child references to it, convert each tenant's row into an
adoption carrying its price and local fields, and only then soft-delete the
duplicate — idempotent, dry-run by default, and counted both before and after.

Development has 147 tenant-scoped `lab_test` rows and 0 platform rows today.
