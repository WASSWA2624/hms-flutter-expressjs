---
alwaysApply: true
---
# Response Format Rules

Purpose: standardize success and error payloads.

Success rules:
- responses return a top-level `success` flag and `data`
- list responses include pagination or cursor metadata in `meta`
- mutation responses return the authoritative current resource or accepted job metadata
- human-facing messages use translation keys or localized strings from the i18n layer

Error rules:
- errors use one normalized problem-details shape
- every error includes stable machine-readable code information
- validation errors include field-level detail when safe
- internal traces, Prisma internals, secrets, and PHI never reach clients
