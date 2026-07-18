# P011 Backend Modules
Implement modules in dependency order while preserving paid-domain boundaries.

## Execution Groups

Modules must be completed in this order:

1. Identity, access, organization, subscriptions, entitlements, and audit.
2. Patient registry, consent, scheduling, and queues.
3. Clinical, inpatient, ICU, theatre, and emergency care.
4. Laboratory, radiology, imaging, and pharmacy.
5. Billing, insurance, workforce, shifts, rosters, and payroll.
6. Inventory, procurement, housekeeping, assets, maintenance, and biomedical.
7. Mortuary, office context, handover, custody snapshots, and closeout.
8. Communications, reporting, analytics, integrations, public services, and cross-domain workspace orchestration.

## Module Gate

- Each module must follow `backend/.cursor/module-creation.mdc` in order.
- Workflows must remain inside their paid module boundaries.
- Permission keys, route families, entitlements, and models must stay aligned with documentation.
- Tests, documentation, and seed changes must be completed together.
- A later group must not begin while required dependencies remain incomplete.
