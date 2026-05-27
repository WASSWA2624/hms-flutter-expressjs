---
alwaysApply: true
---
# Validation Rules

Purpose: make request validation deterministic.

Rules:
- every route has explicit Zod schemas for params, query, and body as needed
- schemas use documented `snake_case` field names
- create and update payloads reject unknown keys unless an owner file explicitly allows passthrough metadata
- IDs, enum values, date ranges, and scope inputs must be validated before service execution
- cross-field business rules belong in services only when they need database context
- validation failures return normalized problem-details responses
- validation schemas are part of the required test surface
