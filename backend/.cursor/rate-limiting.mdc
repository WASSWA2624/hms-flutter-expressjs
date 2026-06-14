---
alwaysApply: true
---
# Rate Limiting Rules

Purpose: protect the API from abuse and runaway automation.

Rules:
- authentication, password reset, invite acceptance, and public endpoints use stricter limits than internal staff CRUD
- rate-limit keys may include IP, tenant, user, or API key depending on endpoint risk
- break-glass and admin routes are not exempt from abuse controls
- repeated failures on sensitive flows should trigger defensive logging or temporary blocking
- limit configuration lives in config, not in route files
