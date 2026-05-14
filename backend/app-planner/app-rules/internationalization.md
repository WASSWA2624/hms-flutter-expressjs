---
alwaysApply: true
---
# Internationalization Rules

Purpose: keep backend locale behavior predictable.

Rules:
- `en` is the baseline locale
- locale resolution may consider user preference, tenant default, and request headers
- backend-generated messages use translation keys or localized message helpers
- stored user-entered clinical, legal, and mortuary notes remain unchanged
- date, time, and number formatting helpers must be locale-aware when formatting leaves the API boundary
