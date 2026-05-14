---
alwaysApply: true
---
# Prisma And Database Rules

Purpose: define the authoritative database contract.

Naming rules:
- Prisma models use lowercase `snake_case`
- database tables and columns use lowercase `snake_case`
- join tables use descriptive `snake_case` names such as `user_role`
- migrations, SQL, queries, and docs must use the same names

Schema rules:
- every tenant-scoped record carries `tenant_id`
- facility-scoped records carry `facility_id` when required by the domain
- auditable records include `created_at`, `updated_at`, and `deleted_at` when soft delete applies
- frequently filtered scope, status, and `deleted_at` columns are indexed
- soft delete is the default for business records unless law or storage design requires otherwise

Data-access rules:
- repositories are the only place for model operations
- service-level Prisma usage is limited to transaction orchestration
- raw SQL requires justification and safe parameterization
- audit evidence must be created for all mutations

Domain-specific requirements:
- workforce access tables must support multi-role assignments and ABAC policy storage
- biomedical tables must preserve equipment lifecycle history
- mortuary tables must preserve custody and release evidence without name drift
