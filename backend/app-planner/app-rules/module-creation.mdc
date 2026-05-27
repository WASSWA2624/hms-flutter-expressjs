---
alwaysApply: true
---
# Module Creation Rules

Purpose: define the mandatory build sequence for every backend module.

Required sequence:
1. define the module contract in `app-write-up.md`, `dev-plan/P010_api_endpoints.md`, and `dev-plan/P011_modules.md`
2. create the module folder and mirrored test folder
3. implement Zod schemas using `snake_case` field names
4. implement repositories with tenancy, soft-delete, and audit-friendly query patterns
5. implement services with RBAC, ABAC, entitlement checks, audit logging, and workflow rules
6. implement controllers with response helpers and no business logic
7. implement routes with validation, auth, authorization, and documentation
8. mount the module and wire any websocket or storage integrations
9. complete tests, seed updates, and doc sync before declaring the module done

Done gate:
- owned tables and permission keys exist
- standalone workflow is usable without another paid module being open
- mutation paths create audit evidence
- route, permission, entitlement, and module names match all docs
- tests pass for schemas, repositories, services, controllers, and routes
