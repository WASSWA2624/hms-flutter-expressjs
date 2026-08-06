# Demo Data: High-Volume Scenario Coverage for Demonstrations

Scale the existing curated demo seed so every demonstrable workspace and demo role account has enough realistic, status-diverse data to walk end-to-end flows—without replacing the seed pipeline, inventing a parallel stack, or seeding production.

## Context

**Current behavior**

- Demo workflow is `db:clear:demo` → `db:seed:demo` → `db:verify:demo` (`clear-demo-data.js`, `seed-demo-data.js`, `verify-demo-data.js`), gated by `demo-safety.js` (refuses production).
- Orchestrator runs curated packs in P012 order: org → access → subscriptions → clinical catalog → clinical → operations → communications → biomedical → mortuary → compliance → governance, then optional `seedFillerPack`.
- Single tenant `DemoCare General Hospital` with one facility; role demo users from `DEMO_TENANTS` / `DEMO_ROLE_CODES` (e.g. `doctor@hosspi.com`, `pharmacy@hosspi.com`, `billing@hosspi.com`) share password `Hosspi@2624.`.
- Curated packs seed **representative** journeys (outpatient, inpatient, lab/radiology, pharmacy, emergency/ambulance, billing, biomedical, mortuary, communications, compliance, closeout)—but at **small counts** (e.g. 5 patients; verify floors like ≥1 appointment, ≥4 encounters, ≥2 payments).
- `seedFillerPack` only tops up **non-`CURATED_MODELS`** with shallow required-field placeholders. Default `seedDemoData({ targetCount: 0 })` **skips filler**; `SEED_RECORD_COUNT` exists in env but CLI `main` hardcodes `targetCount: 0`.
- Verify asserts scenario presence and ownership invariants, **not** 100/1000 row volume or full status-matrix coverage on operational tables.

**Intended behavior**

- After `db:reset:demo` / `db:seed:demo`, a demonstrator logging in as **any seeded demo staff account** sees populated queues, lists, and detail screens that feel like a live facility—not sparse smoke data.
- **Volume**: for each **applicable** application table (see definitions), seed **≥100** rows; prefer **~1000** where volume improves demo fidelity (patients, appointments, encounters, orders, results, invoices/payments, inventory movements, notifications, etc.).
- **Diversity**: rows must mix realistic statuses, outcomes, and edge cases so every major flow state is demonstrable (open/in-progress/completed/cancelled/failed/overdue/pending-review, abnormal vs normal results, paid vs open balances, occupied vs available beds/slots, etc.).
- Preserve curated anchors, deterministic IDs, role accounts, safety gates, and verify; extend packs (or a volume layer that respects FKs/status enums) rather than random orphan rows.

**Definitions**

- *Demo accounts*: users in `DEMO_TENANTS[0].users` with assigned `DEMO_ROLE_CODES` (plus manager extras already seeded).
- *Applicable table*: Prisma models that back list/queue/detail UI or multi-record operational history. **Exclude** singleton/catalog baselines that are intentionally few (e.g. one demo tenant/facility/subscription/license; plan/add-on catalogs; permission/role catalog rows; `_prisma_migrations`). Reference catalogs (lab tests, drugs) may stay at catalog size unless volume is needed for search/demo UX.
- *Scenario-complete*: for each major module journey already seeded, at least one row exists in each meaningful status/outcome the product UI filters on—plus enough volume that filters and pagination feel real.
- *Volume layer*: deterministic expansion of curated packs and/or an FK-aware generator (prefer extending packs over the current shallow filler). Must remain idempotent under upsert/`deterministicUuid` rules.

## Requirements

1. Keep the existing reset/seed/verify/npm scripts and pack order; extend `seed-demo-data` / seeders rather than adding a second demo product. Wire CLI `targetCount` from `SEED_RECORD_COUNT` (default should enable the intended volume targets, not silently stay at 0 unless documented as “curated-only”).
2. For applicable tables, ensure **≥100** seeded rows after a full demo seed; prefer **~1000** for high-traffic operational entities listed under Definitions. Document any intentional exceptions (catalog/singleton) in verify or seeder comments and keep them few.
3. Diversify statuses and scenarios across clinical, diagnostics, pharmacy, billing, reception/scheduling, emergency/ambulance, inventory, biomedical, mortuary, communications, compliance/governance, HR/roster, and reports-related samples so demo accounts can demonstrate complete flows without empty primary screens.
4. Tie volume data to the demo tenant/facility and existing demo users/patients where ownership/ABAC requires it; keep multi-tenant leakage checks in verify.
5. Preserve curated “hero” scenarios currently asserted by `verify-demo-data` (subscription health, conversation variants, break-glass states, biomedical/compliance baselines, role email mapping). Raise verify floors for volume and key status coverage where practical; do not drop existing invariants.
6. Keep seed deterministic (`SEED_RANDOM_SEED`), idempotent upserts, and `demo-safety` production refusal. Clear/reset must still yield a clean demonstrable DB.
7. Update script tests (`seed-demo-data`, `verify-demo-data`, filler/safety as touched) for volume defaults, status diversity smoke checks, and regression of curated invariants. No Flutter feature work unless a seed-only credential helper must stay aligned.

## Constraints

- Reuse `backend/scripts/seed-demo-data.js`, `seeders/*`, `verify-demo-data.js`, `demo-safety.js`, `seed-catalog.js`—no parallel seeder framework.
- Do not seed production; do not weaken RBAC/ABAC by attaching foreign-tenant rows.
- Prefer domain-valid related graphs over filler that only satisfies non-null scalars.
- No unrelated app/UI refactors; follow `backend/dev-plan/P012_seeder.md`, `.cursor/mandatories.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | `npm run db:reset:demo` (or clear+seed) completes and verify passes. | R1, R5–R6 |
| A2 | Applicable operational tables have ≥100 rows; high-traffic ones target ~1000 where applicable; documented exceptions only for catalog/singletons. | R2 |
| A3 | Major module status mixes are present so demo role logins show non-empty, filterable queues/lists for their domains. | R3–R4 |
| A4 | Existing curated verify invariants (roles, subscription, communications, biomedical/compliance, break-glass) still pass. | R5 |
| A5 | Production seed/clear still refused; seed remains deterministic for fixed `SEED_RANDOM_SEED`. | R6 |
| A6 | Script tests cover volume/default wiring and curated regression. | R7 |

## Relevant Files

- `backend/scripts/seed-demo-data.js`, `clear-demo-data.js`, `verify-demo-data.js`, `demo-safety.js`
- `backend/scripts/seeders/seed-runtime.js`, `seed-catalog.js`, `seed-*-pack.js`, `seed-filler-pack.js`
- `backend/package.json` (`db:seed:demo`, `db:reset:demo`, `db:verify:demo`); `backend/src/config/env.js` (`SEED_RECORD_COUNT`, `SEED_RANDOM_SEED`)
- Tests: `backend/src/tests/scripts/seed-demo-data.test.js`, `verify-demo-data.test.js`, `clear-demo-data.test.js`, `demo-safety.test.js`
- Reference: `backend/scripts/README.md`, `backend/dev-plan/P012_seeder.md`

## Verification

- Backend: reset+seed+verify; spot-count applicable tables (≥100 / ~1000); confirm status diversity on appointments, encounters, lab/pharmacy/billing, biomedical, mortuary, communications.
- Manual: log in as receptionist, doctor, lab, pharmacy, billing, biomed, mortuary—primary lists/queues populated; walk one complete flow each. Confirm curated hero scenarios still findable.
- Tests: volume default / curated-only mode if retained; verify floors; production skip.
