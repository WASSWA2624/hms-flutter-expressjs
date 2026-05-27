---
alwaysApply: true
---
# API Rules

Purpose: keep the HTTP surface consistent and predictable.

Route rules:
- versioned business endpoints live under `/api/v1/*`
- health endpoints remain unversioned at `/health`, `/ready`, and `/live`
- resource paths use plural kebab-case segments
- path parameters use route-safe names such as `:id`
- query parameters and documented JSON fields use `snake_case`
- list endpoints support pagination, filtering, and sorting consistently
- action endpoints use `POST /resource/:id/<action>` only when CRUD is insufficient
- workspace endpoints may aggregate module-owned summaries but must stay inside module scope

Middleware order:
1. request context
2. validation
3. authentication
4. entitlement check
5. RBAC and ABAC authorization
6. controller handler
7. centralized error middleware

Contract rules:
- no business logic in routes
- no undocumented custom verbs
- no route may bypass tenancy or facility scope rules
