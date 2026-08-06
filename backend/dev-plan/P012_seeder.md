# P012 Seeder
Provide reproducible data that exercises every major backend workflow.

## Seed Order

Seed data must be created in this order:

1. Organization, access, permissions, and entitlements.
2. Patient registry, scheduling, clinical, and diagnostic catalogs.
3. Pharmacy, inventory, billing, coverage, and subscription baselines.
4. Workforce, roster, unit management, facilities, assets, and biomedical equipment.
5. Mortuary cases and storage structures.
6. Notifications, reporting, integrations, handover, and closeout samples.
7. Volume expansion (`seed-volume-pack`) for applicable operational tables, then optional filler.

## Script Policy

- Existing seed families should be extended before adding script names.
- `seed-demo-data`, verification, and catalog scripts must follow this order.
- Volume mode defaults to ~1000 high-traffic rows (`SEED_RECORD_COUNT`); use `0` for curated-only.
- Obsolete helpers must be removed when their replacements land.

## Acceptance

Seeded tenants must exercise Mortuary, biomedical, roster management, and every other major workflow family deterministically.
