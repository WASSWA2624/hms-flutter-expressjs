# P003 Application Bootstrap
Make the backend bootable without later modules changing startup behavior.

## Bootstrap

- Build the Express application and root router.
- Mount `/health`, `/ready`, `/live`, and `/api/v1`.
- Validation, authentication, entitlements, authorization, and error handling must run in the canonical order.
- Add graceful shutdown and startup diagnostics.

## Acceptance

- Development and test startup must complete cleanly.
- Health endpoints must report their intended states correctly.
- Module routes must be mountable without modifying bootstrap semantics.
