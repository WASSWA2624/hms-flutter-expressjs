---
alwaysApply: true
---
# Backend Rules Index

Purpose: define backend technical standards for `hms-backend`.

Conflict order:
1. security, privacy, safety, and compliance rules
2. the owner file named in this index
3. other backend rule files
4. backend dev-plan files

Backend-wide invariants:
- Express.js and CommonJS are mandatory.
- Database objects, Prisma models, schema fields, and documented payload fields use lowercase `snake_case`.
- Multi-role access is resolved through `user_role` plus RBAC, ABAC, entitlements, and audited break-glass access.
- Every business module must stay standalone and entitlement-aware.
- Public APIs and complex logic require JSDoc-style documentation.
- Only essential scripts may remain in `scripts/` and `prisma/scripts/`.
- Circular dependencies are forbidden.

Owner map:
- `architecture.md`: runtime, layering, dependency direction
- `project-structure.md`: folder ownership and script categories
- `coding-standards.md`: naming, comments, reuse, code style
- `import-aliases.md`: aliases and import boundaries
- `module-creation.md`: required module build sequence
- `api.md`: route shape and middleware order
- `api-versioning.md`: version lifecycle
- `response-format.md`: success and error envelopes
- `validation.md`: request validation rules
- `auth-security.md`: authn, authz, roles, ABAC, entitlements, break-glass
- `cors.md`, `rate-limiting.md`, `health-checks.md`, `error-logging.md`, `constants-env.md`: runtime safety and operations
- `prisma.md`, `storage.md`, `websockets.md`, `performance.md`, `offline-support.md`, `internationalization.md`: platform behavior
- `compliance.md`, `documentation.md`, `testing.md`: governance and quality gates
