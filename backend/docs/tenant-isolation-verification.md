# Tenant Isolation Verification

**Fairbanks fixes — Phase 2, step 07.** The phase gate: proving that no data,
configuration or access crosses a tenant boundary.

> **Status: partial.** The database, authorization and automated-test layers are
> verified on development. The UI sweep and the production pass are **not** done,
> and step 06 is still in progress — see [§7](#7-what-is-not-yet-proven).

| | |
| :--- | :--- |
| Branch | `step-06-platform-presets` |
| Development schema head | `20260912020000_platform_preset_scope` |
| Production schema head | `20260911140000_session_lifetime_policy` — **behind development** |
| Verified on | Development only |

---

## 1. Headline finding

**A real isolation defect was found and fixed.** Step 06 added a platform preset
tier (`tenant_id IS NULL`) to five catalog models, but the database-level tenant
guard only recognised `role` and `permission` as platform-shared. Every one of
the 2,169 presets was therefore **invisible to every tenant** through the normal
request path.

Measured before the fix, inside a tenant request context:

| Model | Visible | Should be |
| :--- | ---: | ---: |
| `lab_test` | 147 (tenant's own only) | 294 |
| `drug` | 100 (tenant's own only) | 200 |
| `role` | 185 (already shared) | 185 |

The five definition models are now registered in `PLATFORM_SHARED_MODELS`
([tenant-guard.js](../src/prisma/tenant-guard.js)), which widens reads to
`OR: [{ tenant_id }, { tenant_id: null }]` and preserves an explicit
`tenant_id: null` on write.

**Crucially, this widened nothing else.** Re-measured as a tenant that owns no
catalog at all:

```
lab_test visible to tenant B: 147 (own 0, platform 147, FOREIGN 0)
patient  visible to tenant B: 0          (the demo tenant sees 1,008)
invoice  visible to tenant B: 0
```

The relaxation is exactly `tenant_id: null` and nothing more.

---

## 2. Enforcement architecture

Isolation is enforced at three layers, each independently tested.

| Layer | Mechanism | Where |
| :--- | :--- | :--- |
| Request | `enforceTenantScope()` rewrites `tenant_id`/`facility_id` in query and body to the actor's own, for any non-elevated role | [tenant-scope.middleware.js](../src/middlewares/tenant-scope.middleware.js) |
| Authorization | `enforceAbacAccess()` after scope hydration | [abac.middleware.js](../src/middlewares/abac.middleware.js) |
| Database | Prisma query extension injecting a tenant constraint into every read, write and aggregate | [tenant-guard.js](../src/prisma/tenant-guard.js) |

The request layer normalises **payloads**; it does not protect a direct
identifier in a path parameter. That protection comes from the database layer,
which scopes `findUnique` by rewriting it to a guarded `findFirst` — so a
crafted `GET /patients/<other-tenant-id>` returns not-found rather than the row.

---

## 3. Route coverage — AC3

Coverage is **structural, not audited**. The router mounts the guard chain once
on the v1 router, ahead of every module:

```
apiV1Router.use('/auth', …)      ← pre-auth by design
apiV1Router.use('/public', …)    ← unauthenticated by design
apiV1Router.use(authenticate());
apiV1Router.use(hydrateRequestScope());
apiV1Router.use(enforceTenantScope());
apiV1Router.use(hydrateRequestContext());   ← what the database guard reads
apiV1Router.use(enforceModuleEntitlement());
apiV1Router.use(enforceAbacAccess());
…211 module routes…
```

| | |
| :--- | ---: |
| Module routes mounted after tenant-scope enforcement | **211** |
| Module routes mounted before it | **2** (`/auth`, `/public`) |
| Unenforced tenant-scoped routes | **0** |

A new module is enforced the moment it is mounted; nobody has to remember to add
a guard. That property is pinned by
[`tenant-scope-route-coverage.test.js`](../src/tests/app/tenant-scope-route-coverage.test.js),
which fails if a module is ever mounted ahead of the chain or the ordering
changes.

Both pre-auth routes were checked and neither is tenant-scoped: `/auth` issues
the token, `/public` serves unauthenticated content.

---

## 4. Automated tests — AC6

| Suite | Tests | Covers |
| :--- | ---: | :--- |
| [`cross-tenant-access.test.js`](../src/tests/prisma/cross-tenant-access.test.js) | 48 | Direct-identifier read, list, count, updateMany, deleteMany and create across `patient`, `encounter`, `invoice`, `payment`, `visit_queue`, `facility` |
| [`tenant-guard.platform-models.test.js`](../src/tests/prisma/tenant-guard.platform-models.test.js) | 9 | The platform tier is shared, adoption and operational tables are not |
| [`tenant-scope-route-coverage.test.js`](../src/tests/app/tenant-scope-route-coverage.test.js) | 8 | Mount ordering, 211 routes covered |
| [`platform-preset-immutability.test.js`](../src/tests/modules/catalog/platform-preset-immutability.test.js) | 11 | A tenant cannot write a platform definition or another tenant's |
| [`preset-ownership.test.js`](../src/tests/lib/catalog/preset-ownership.test.js) | 41 | Ownership model, scope resolution, override limits |

Each covered model is asserted on six operations, and creates are checked to
**ignore a forged `tenant_id`** in the body — the guard stamps the acting tenant
regardless of what the caller claims.

### 4.1 The suite fails when a guard is removed

Required by AC6, and verified rather than assumed. Deleting the tenant
constraint from `buildGuardedWhere`:

| | Tests |
| :--- | :--- |
| Guard removed | **33 failed**, 36 passed |
| Guard restored | **69 passed**, 0 failed |

The drift test was checked the same way: removing one preset model from
`PLATFORM_SHARED_MODELS` fails it.

---

## 5. Preset and configuration isolation — AC5 (partial)

What holds today:

- A tenant reads the platform catalog plus its own entries, never another
  tenant's — measured in §1 and asserted in `tenant-guard.platform-models.test.js`.
- A tenant cannot update or delete a platform definition: 403, not a 404 that
  hides the row's existence.
- A tenant cannot write another tenant's definition.
- Adoption tables are never platform-shared, so one tenant's prices and
  availability cannot be read by another.

What cannot be closed yet: step 06's **adoption API does not exist**, so "a
preset *adopted* in tenant A leaves tenant B unchanged" cannot be exercised
end to end. The underlying guarantee — adoption rows are tenant-scoped and never
shared — is asserted, but the user-facing flow is untested because it is unbuilt.

---

## 6. Database and query layer — AC4

Every read, write and aggregate through the Prisma client passes the tenant
guard extension. `findUnique` is rewritten to a guarded `findFirst`, so
identifier lookups cannot bypass the filter.

Two bypasses exist by design and were reviewed:

| Bypass | When it applies | Assessment |
| :--- | :--- | :--- |
| Elevated roles | `PLATFORM_OWNER`, `PLATFORM_ADMIN` only — `TENANT_ADMIN` is **not** elevated | Correct: platform operators are cross-tenant by definition |
| `runWithoutTenantGuard()` | Explicit, in-process, for platform catalog reads | Correct, but each call site is worth re-reviewing in step 48 |

### 6.1 Raw queries

`$queryRaw` and `$executeRaw` bypass the extension entirely, so each call site
was reviewed. There are 23, in 8 files:

| File | Calls | What they do |
| :--- | ---: | :--- |
| `department.repository.js` | 6 | `information_schema` lookup, then cascade `DELETE` by `department_id` / `unit_id` |
| `tenant.repository.js` | 5 | Same shape, scoped to a resolved tenant |
| `facility.repository.js` | 4 | Same shape, scoped to a resolved facility |
| `prisma/client.js` | 2 | Friendly-id sequence reservation |
| `health/startupDatabaseCheck.js` | 2 | `SELECT 1`, column existence |
| `health/readinessCheck.js` | 2 | `SELECT 1` |
| `reports/runtime.js`, `notifications/runtime.js` | 2 | Queue drains |

None selects tenant-scoped business data by a caller-supplied filter. The
repository cases are hard-delete cascades operating on an id that was **already
resolved through a guarded query**, so the tenant scoping comes from the caller
rather than from the SQL. That is sound but it is enforcement by convention, not
by construction — it would not survive someone calling those helpers with an
unvalidated id.

Recorded rather than changed here: tightening it belongs with the authorization
audit in step 48, which reviews these call sites in their own right.

---

## 7. What is not yet proven

| AC | Gap | Why |
| :--- | :--- | :--- |
| **AC1** | No UI sweep | Requires two live tenants and a manual pass at representative viewports and themes |
| **AC2** | API probes not run against a live server | The database-layer guarantee is tested; authenticated HTTP probes with two real tokens are not |
| **AC5** | Adoption flow untestable | Step 06's adoption API is unbuilt |
| **AC7** | **Production not verified** | Production is a migration behind, and step 06 has not been deployed |
| R5 | Raw queries rely on caller-side scoping | All 23 call sites reviewed (§6.1); none leaks, but the guarantee is by convention. Tightening belongs to step 48. |

**This gate is not passed.** Step 07 says no later step may be marked complete
until it passes in both environments, and the production half has not run.

### 7.1 Sequencing

Step 07 depends on 04, 05 and 06. Steps 04 and 05 are complete and deployed;
**step 06 is not** — the collapse, adoption API, currency and consultation
preset tables, frontend surfaces and production rollout are all outstanding
([platform-presets-model.md](platform-presets-model.md) §3.2).

The layers verified here are the ones that do not depend on step 06's remaining
work, and the defect in §1 was worth finding now rather than after. The
remaining criteria should be closed once step 06 lands, in this order:

1. Deploy step 06 (schema + code) to production.
2. Register two tenants per environment through the normal registration flow.
3. Run the API probes with both tokens (AC2) and the UI sweep (AC1).
4. Exercise preset adoption in tenant A, confirm B is unchanged (AC5).
6. Remove the verification tenants with a logged cleanup.
