# P002 Prisma

Goal: establish the database runtime and naming contract.

Do:
- configure the Prisma client, adapter, and connection lifecycle
- enforce lowercase `snake_case` models, tables, columns, migration names, and docs
- create tenancy, access, audit, entitlement, and baseline operational schema support
- prepare indexes, soft-delete fields, and migration workflow for later domain phases

Acceptance:
- migrations run cleanly in order
- repository access can rely on stable `tenant_id`, `facility_id`, and audit fields
- no schema naming drift exists between Prisma, SQL, and docs
