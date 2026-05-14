# P012 Seeder

Goal: provide deterministic seed data for development and verification.

Seed order:
1. org, access, permissions, entitlements
2. patient registry and scheduling reference data
3. clinical and diagnostic catalogs
4. pharmacy and inventory baselines
5. billing, coverage, and subscription plans
6. workforce, roster, and unit-management data
7. facilities, assets, and biomedical equipment packs
8. Mortuary sample cases and storage structures
9. notifications, reporting, integrations, and closeout samples

Script policy:
- reuse and extend existing seed families before adding new script names
- keep `seed-demo-data`, verification, and catalog scripts aligned with this order
- remove obsolete seed helpers in the same change that makes them obsolete

Acceptance:
- seeded tenants can exercise every major workflow family, including Mortuary, biomedical, and roster management
