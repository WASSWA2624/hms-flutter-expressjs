---
alwaysApply: true
---
# Error And Logging Rules

Purpose: normalize failures and keep logs safe.

Rules:
- routes and services throw typed errors or safe domain errors only
- the global error middleware maps failures to the canonical problem-details response
- application logs are structured and include request, tenant, facility, user, module, and action context when available
- secrets, access tokens, raw credentials, and PHI must be redacted
- audit logs are separate from application logs
- console noise and duplicate logging are defects
