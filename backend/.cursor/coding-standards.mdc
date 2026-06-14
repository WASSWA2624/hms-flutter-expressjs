---
alwaysApply: true
---
# Coding Standards

Purpose: keep backend code uniform, reusable, and reviewable.

Rules:
- CommonJS only.
- Module folders use kebab-case. Functions use camelCase. Constants use `UPPER_SNAKE_CASE`.
- Database, Prisma model, schema, migration, and documented payload field names use lowercase `snake_case`.
- Prefer small reusable services and helper functions over copy-paste implementations.
- Public functions, exported modules, and complex logic require JSDoc-style multi-line comments.
- Inline comments explain intent, assumptions, or edge cases only.
- Do not read `process.env` outside config helpers.
- Do not hardcode authorization, entitlement, or role logic inside controllers.
- Do not add duplicate helper libraries or one-off scripts when an existing family can be extended.
- Circular dependencies, dead files, and stale comments are defects.
